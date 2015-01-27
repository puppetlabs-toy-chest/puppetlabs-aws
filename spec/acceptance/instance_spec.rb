require 'spec_helper_acceptance'
require 'securerandom'
require 'ipaddr'

describe "ec2_instance" do

  before(:all) do
    @default_region = 'sa-east-1'
    @aws = AwsHelper.new(@default_region)
    @template = 'instance.pp.tmpl'
  end

  def get_instance(name)
    instances = @aws.get_instances(name)
    expect(instances.count).to eq(1)
    instances.first
  end

  describe 'should create a new instance' do

    before(:all) do
      @config = {
        :name => "#{PuppetManifest.env_id}-#{SecureRandom.uuid}",
        :instance_type => 't1.micro',
        :region => @default_region,
        :image_id => 'ami-41e85d5c',
        :ensure => 'present',
        :tags => {
          :department => 'engineering',
          :project    => 'cloud',
          :created_by => 'aws-acceptance'
        }
      }

      PuppetManifest.new(@template, @config).apply
      @instance = get_instance(@config[:name])
    end

    after(:all) do
      @aws.ec2_client.wait_until(:instance_running, instance_ids:[@instance.instance_id])

      new_config = @config.update({:ensure => 'absent'})
      PuppetManifest.new(@template, new_config).apply

      @aws.ec2_client.wait_until(:instance_terminated, instance_ids:[@instance.instance_id])
    end

    it "with the specified name" do
      expect(@instance.tags.detect { |tag| tag.key == 'Name' }.value).to eq(@config[:name])
    end

    it "with the specified tags" do
      expect(@aws.tag_difference(@instance, @config[:tags])).to be_empty
    end

    it "with the specified type" do
      expect(@instance.instance_type).to eq(@config[:instance_type])
    end

    it "with the specified AMI" do
      expect(@instance.image_id).to eq(@config[:image_id])
    end

    it "and return hypervisor, virtualization_type properties" do
      expect(@instance.hypervisor).to eq('xen')
      expect(@instance.virtualization_type).to eq('paravirtual')
    end

    it "and return public_dns_name, private_dns_name,
      public_ip_address, private_ip_address" do
      pending('we return instance on pending, and not running, and
        also need to provide better validation around the values')
      expect(@instance.public_dns_name).to match(/\.compute\.amazonaws\.com/)
      expect(@instance.private_dns_name).to match(/\.compute\.internal/)
      expect{ IPAddr.new(@instance.public_ip_address) }.not_to raise_error
      expect{ IPAddr.new(@instance.private_ip_address) }.not_to raise_error
    end

  end

  describe 'should not create a new instance' do
    before(:each) do
      @config = {
        :name => "#{PuppetManifest.env_id}-#{SecureRandom.uuid}",
        :instance_type => 't1.micro',
        :region => @default_region,
        :image_id => 'ami-41e85d5c',
        :ensure => 'present',
        :tags => {
          :department => 'engineering',
          :project    => 'cloud',
          :created_by => 'aws-acceptance'
        }
      }
    end

    def expect_failed_apply(config)
      success = PuppetManifest.new(@template, config).apply[:exit_status].success?
      expect(success).to eq(false)

      expect(@aws.get_instances(config[:name])).to be_empty
    end

    it 'with an invalid name' do
      @config[:name] = ''
      expect_failed_apply(@config)
    end

    it 'with an empty AMI' do
      @config[:image_id] = ''
      expect_failed_apply(@config)
    end

    it 'with an empty region' do
      # empty string error propagates from AWS toolkit
      # whitespace propagates from our code
      ['', ' '].each do |region|
        @config[:region] = region
        expect_failed_apply(@config)
      end
    end

    it 'with an empty availability zone' do
      @config[:optional] = {:availability_zone => '' }
      expect_failed_apply(@config)
    end

    read_only = [
      {:instance_id => 'foo'}, {:hypervisor => 'foo'},
      {:virtualization_type => 'foo'}, {:private_ip_address => 'foo'},
      {:public_ip_address => 'foo'}, {:private_dns_name => 'foo'},
      {:public_dns_name => 'foo'},
    ]

    read_only.each do |new_config_value|
      it "when trying to set read-only property #{new_config_value.first[0]}" do
        # :optional is special and allows injecting optional config into template
        new_config = @config.update({:optional => new_config_value})

        expect_failed_apply(new_config)
      end
    end
  end

  describe 'should create a new instance' do

    before(:each) do
      @config = {
        :name => "#{PuppetManifest.env_id}-#{SecureRandom.uuid}",
        :instance_type => 't1.micro',
        :region => 'sa-east-1',
        :image_id => 'ami-41e85d5c',
        :ensure => 'present',
        :tags => {
          :department => 'engineering',
          :project    => 'cloud',
          :created_by => 'aws-acceptance'
        }
      }

      PuppetManifest.new(@template, @config).apply
      @instance = get_instance(@config[:name])
    end

    after(:each) do
      @config[:ensure] = 'absent'
      PuppetManifest.new(@template, @config).apply

      @aws.ec2_client.wait_until(:instance_terminated, instance_ids:[@instance.instance_id])
    end

    it 'that can have tags changed' do
      @aws.ec2_client.wait_until(:instance_running, instance_ids:[@instance.instance_id])
      expect(@aws.tag_difference(@instance, @config[:tags])).to be_empty

      tags = {:created_by => 'aws-tests', :foo => 'bar'}
      @config[:tags].update(tags)

      PuppetManifest.new(@template, @config).apply
      @instance = get_instance(@config[:name])
      expect(@aws.tag_difference(@instance, @config[:tags])).to be_empty
    end

    it "that can be stopped and restarted" do
      @aws.ec2_client.wait_until(:instance_running, instance_ids:[@instance.instance_id])

      @config[:ensure] = 'stopped'
      PuppetManifest.new(@template, @config).apply

      @aws.ec2_client.wait_until(:instance_stopped, instance_ids:[@instance.instance_id])

      @config[:ensure] = 'present'
      PuppetManifest.new(@template, @config).apply
      @aws.ec2_client.wait_until(:instance_running, instance_ids:[@instance.instance_id])
    end
  end

  describe 'create a new instance' do

    let(:config) do
      {
        :name => "#{PuppetManifest.env_id}-#{SecureRandom.uuid}",
        :instance_type => 't1.micro',
        :region => 'sa-east-1',
        :image_id => 'ami-41e85d5c',
        :ensure => 'present',
        :tags => {
          :department => 'engineering',
          :project    => 'cloud',
          :created_by => 'aws-acceptance'
        }
      }
    end

    after(:each) do
      config[:ensure] = 'absent'
      PuppetManifest.new(@template, config).apply
    end

    it 'launched as stopped' do
      config[:ensure] = 'stopped'
      r = PuppetManifest.new(@template, config).apply
      expect(r[:output].any?{ |o| o.include?('Error:')}).to eq(false)
      instance = get_instance(config[:name])
      @aws.ec2_client.wait_until(:instance_stopped, instance_ids:[instance.instance_id])
    end

    it 'launched as running' do
      config[:ensure] = 'running'
      r = PuppetManifest.new(@template, config).apply
      expect(r[:output].any?{ |o| o.include?('Error:')}).to eq(false)
      instance = get_instance(config[:name])
      @aws.ec2_client.wait_until(:instance_running, instance_ids:[instance.instance_id])
    end
  end
end
