require 'spec_helper_acceptance'
require 'securerandom'
require 'beaker_configure'
require 'pry'

describe 'User Scenario for overlapping security groups' do

  before(:all) do
    @template = 'integration_2.pp.tmpl'
    @region = 'sa-east-1'
    @aws = AwsHelper.new(@region)
    @provisioner = find_only_one(:provisioner)
    @random = SecureRandom.uuid
    @group_name_1 = "1-sg-#{PuppetManifest.env_id}-#{@random}"
    @instance_name_1 = "ec2-1-#{PuppetManifest.env_id}-#{@random}"
    @group_name_2 = "2-sg-#{PuppetManifest.env_id}-#{@random}"
    @instance_name_2 = "ec2-2-#{PuppetManifest.env_id}-#{@random}"
    @group_name_3 = "3-sg-#{PuppetManifest.env_id}-#{@random}"
    @instance_name_3 = "ec2-3-#{PuppetManifest.env_id}-#{@random}"
    @instance_name_4 = "ec2-4-#{PuppetManifest.env_id}-#{@random}"
  end

  context 'PMT install' do
    it 'install puppetlabs/aws from the staging forge' do
      on(master, puppet("module install puppetlabs-aws --version #{ENV['PKG_VERSION']} --module_repository=#{ENV['SPEC_FORGE']}"))
    end
  end

  context 'Apply a manifest to create the AWS infastructure' do

    before(:all) do
      #use mustache to build a manifest that can be applied
      @config = {
        :group_name_1           => @group_name_1,
        :group_description_1    => 'A security group for ec2 2 and 4',
        :group_name_2           => @group_name_2,
        :group_description_2    => 'A security group for ec2 3 and 4',
        :group_name_3           => @group_name_3,
        :group_description_3    => 'A Security group with no instances',
        :instance_name_1        => @instance_name_1,
        :instance_1_sg          => ['default'],
        :instance_name_2        => @instance_name_2,
        :instance_2_sg          => [@group_name_1],
        :instance_name_3        => @instance_name_3,
        :instance_3_sg          => [@group_name_2],
        :instance_name_4        => @instance_name_4,
        :instance_4_sg          => [@group_name_1, @group_name_2],
        :instance_type          => 't1.micro',
        :ec2_availability_zone  => "#{@region}-1a",
        :region                 => @region,
        :image_id               => 'ami-41e85d5c',
        :ensure                 => 'present',
        :tags => {
          :department => 'engineering',
          :project    => 'cloud',
          :created_by => 'aws-acceptance'
        },
        :ingress => [
          {
            :protocol => 'tcp',
            :port     => 22,
            :cidr     => '0.0.0.0/0'
          }
        ],
      }
      # create site.pp on master
      @manifest = PuppetManifest.new(@template, @config).render
      on(master, 'rm -f /etc/puppetlabs/puppet/manifests/site.pp')
      create_remote_file(master, '/etc/puppetlabs/puppet/environments/production/manifests/site.pp', @manifest)
      on(master, 'chmod 777 /etc/puppetlabs/puppet/environments/production/manifests/site.pp')
      # initiate a puppet run
      on(@provisioner, puppet('agent --test'), {:acceptable_exit_codes => [0,2]})
    end

    it 'ec2 instances created' do
      expect{ @aws.get_instance(@config[:instance_name_1])}.not_to raise_error
      expect{ @aws.get_instance(@config[:instance_name_2])}.not_to raise_error
      expect{ @aws.get_instance(@config[:instance_name_3])}.not_to raise_error
      expect{ @aws.get_instance(@config[:instance_name_4])}.not_to raise_error
    end

    it 'ec2 security group created' do
      expect{ @aws.get_group(@config[:group_name_1])}.not_to raise_error
      expect{ @aws.get_group(@config[:group_name_2])}.not_to raise_error
      expect{ @aws.get_group(@config[:group_name_3])}.not_to raise_error
    end

    it 'instance 1 is in the correct security groups' do
      security_groups = @aws.get_instance(@config[:instance_name_1]).security_groups
      expect(security_groups.first.to_s).to match(/default/)
    end

    it 'instance 2 is in the correct security groups' do
      security_groups = @aws.get_instance(@config[:instance_name_2]).security_groups
      expect(security_groups.first.to_s).to match(/#{@group_name_1}/)
    end

    it 'instance 3 is in the correct security groups' do
      security_groups = @aws.get_instance(@config[:instance_name_3]).security_groups
      expect(security_groups.first.to_s).to match(/#{@group_name_2}/)
    end

    it 'instance 4 is in the correct security groups' do
      security_groups = @aws.get_instance(@config[:instance_name_4]).security_groups
      expect(security_groups).to satisfy do |sg|
        g1 = sg.any?{ |g| /#{@group_name_1}/.match(g.to_s)}
        g2 = sg.any?{ |g| /#{@group_name_2}/.match(g.to_s)}
        g1 == true && g2 == true
      end
    end

  end

  context 'teardown the ec2 instances' do

    before(:all) do
      on(@provisioner, puppet("resource ec2_instance #{@instance_name_1} ensure=absent region=#{@region}"))
      on(@provisioner, puppet("resource ec2_instance #{@instance_name_2} ensure=absent region=#{@region}"))
      on(@provisioner, puppet("resource ec2_instance #{@instance_name_3} ensure=absent region=#{@region}"))
      on(@provisioner, puppet("resource ec2_instance #{@instance_name_4} ensure=absent region=#{@region}"))
    end

    it 'ec2 instances removed' do
      expect{@aws.get_instance(@config[:instance_name_1])}.to raise_error
      expect{@aws.get_instance(@config[:instance_name_2])}.to raise_error
      expect{@aws.get_instance(@config[:instance_name_3])}.to raise_error
      expect{@aws.get_instance(@config[:instance_name_4])}.to raise_error
    end

  end

  context 'teardown the security groups' do

    before(:all) do
      on(@provisioner, puppet("resource ec2_securitygroup #{@group_name_1} ensure=absent region=#{@region}"))
      on(@provisioner, puppet("resource ec2_securitygroup #{@group_name_2} ensure=absent region=#{@region}"))
      on(@provisioner, puppet("resource ec2_securitygroup #{@group_name_3} ensure=absent region=#{@region}"))
    end

    it 'security groups removed' do
      expect{@aws.get_group(@config[:group_name_1])}.to raise_error
      expect{@aws.get_group(@config[:group_name_2])}.to raise_error
      expect{@aws.get_group(@config[:group_name_3])}.to raise_error
    end

  end

end
