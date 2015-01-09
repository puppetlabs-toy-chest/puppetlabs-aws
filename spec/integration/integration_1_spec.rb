require 'spec_helper_acceptance'
require 'securerandom'
require 'beaker_configure'

describe 'User Scenario via PMT master & agent' do

  before(:all) do
    @template = 'integration_1.pp.tmpl'
    @region = 'sa-east-1'
    @aws = AwsHelper.new(@region)
    @provisioner = find_only_one(:provisioner)
    @random = SecureRandom.uuid
    @group_name = "group-#{PuppetManifest.env_id}-#{@random}"
    @instance_name = "instance-#{PuppetManifest.env_id}-#{@random}"
    @elb_name = "elb-#{PuppetManifest.env_dns_id}#{@random}".gsub('-', '')[0...31]
  end

  context 'PMT install' do
    it 'installs from the staging forge' do
      on(master, puppet("module install puppetlabs-aws --version #{ENV['PKG_VERSION']} --module_repository=#{ENV['SPEC_FORGE']}"))
    end
  end

  context 'Apply a manifest that excercizes all the types in the module' do

    before(:all) do
      #use mustache to build a manifest that can be applied
      @config = {
        :elb_name => @elb_name,
        :group_name => @group_name,
        :instance_name => @instance_name,
        :instance_type => 't1.micro',
        :ec2_availability_zone => 'sa-east-1a',
        :region => @region,
        :image_id => 'ami-41e85d5c',
        :ensure => 'present',
        :tags => {
          :department => 'engineering',
          :project    => 'cloud',
          :created_by => 'aws-acceptance'
        },
        :group_description => 'A Test Security Group',
        :ingress => [
          {
            :security_group => @group_name,
          },{
            :protocol => 'tcp',
            :port     => 22,
            :cidr     => '0.0.0.0/0'
          }
        ],
        :elb_availability_zones => 'sa-east-1a',
        :listeners => [
          {
            :protocol => 'tcp',
            :port     => 80,
          }
          ],
        :balanced_instances => [@instance_name],
      }
      # create site.pp on master
      @manifest = PuppetManifest.new(@template, @config).render
      on(master, 'rm -f /etc/puppetlabs/puppet/manifests/site.pp')
      create_remote_file(master, '/etc/puppetlabs/puppet/environments/production/manifests/site.pp', @manifest)
      on(master, 'chmod 777 /etc/puppetlabs/puppet/environments/production/manifests/site.pp')
      # initiate a puppet run
      on(@provisioner, puppet('agent --test'), {:acceptable_exit_codes => [0,2]})
    end

    after(:all)
      @instance = @aws.get_instance(@config[:instance_name])
      @aws.ec2_client.wait_until(:instance_running, instance_ids:[@instance.instance_id])
      on(@provisioner, "puppet resource ec2_instance #{@instance_name} ensure=absent")
      @aws.ec2_client.wait_until(:instance_terminated, instance_ids:[@instance.instance_id])
      on(@provisioner, "puppet resource ec2_security_group #{@security_group_name} ensure=absent")
      expect { @aws.find_group(@config[:group_name]) }.to raise_error(Aws::EC2::Errors::InvalidGroupNotFound)
      on(@provisioner, "puppet resource elb_loadbalancer #{@elastic_load_balancer_name} ensure=absent")
      expect { @aws.load_balancer(@config[:elb_name])}.to raise_error(Aws::ELB::some_fun_error)
    end

    it 'ec2 instance created' do
      expect{ @aws.get_instance(@config[:instance_name])}.not_to raise_error
    end

    it 'ec2 security group created' do
      expect{ @aws.get_group(@config[:group_name])}.not_to raise_error
    end

    it 'elastic load balancer created' do
      expect{ @aws.get_loadbalancer(@config[:elb_name])}.not_to raise_error
    end

  end

end
