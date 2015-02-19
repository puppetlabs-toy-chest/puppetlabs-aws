require 'spec_helper_acceptance'
require 'securerandom'
require 'ipaddr'

describe "ec2_instance" do

  before(:all) do
    @default_region = 'sa-east-1'
    @default_availability_zone = "#{@default_region}a"
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
        :image_id => 'ami-67a60d7a',
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

    it "not associated with a VPC" do
      skip('VPC only accounts will fail here')
      expect(@instance.subnet_id).to be_nil
      expect(@instance.vpc_id).to be_nil
    end

    it "and return hypervisor, virtualization_type properties" do
      expect(@instance.hypervisor).to eq('xen')
      expect(@instance.virtualization_type).to eq('paravirtual')
    end

    it "and return public_dns_name, private_dns_name,
      public_ip_address, private_ip_address" do
      @aws.ec2_client.wait_until(:instance_running, instance_ids: [@instance.instance_id])
      instance = get_instance(@config[:name])
      expect(instance.public_dns_name).to match(/\.compute\.amazonaws\.com/)
      expect(instance.private_dns_name).to match(/\.compute\.internal/)
      expect{ IPAddr.new(instance.public_ip_address) }.not_to raise_error
      expect{ IPAddr.new(instance.private_ip_address) }.not_to raise_error
    end

  end

  describe 'should not create a new instance' do
    before(:each) do
      @config = {
        :name => "#{PuppetManifest.env_id}-#{SecureRandom.uuid}",
        :instance_type => 't1.micro',
        :region => @default_region,
        :image_id => 'ami-67a60d7a',
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
        :image_id => 'ami-67a60d7a',
        :ensure => 'present',
        :tags => {
          :department => 'engineering',
          :project    => 'cloud',
          :created_by => 'aws-acceptance'
        }
      }

      PuppetManifest.new(@template, @config).apply
      @instance = get_instance(@config[:name])
      @aws.ec2_client.wait_until(:instance_running, instance_ids:[@instance.instance_id])
    end

    after(:each) do
      @config[:ensure] = 'absent'
      PuppetManifest.new(@template, @config).apply

      @aws.ec2_client.wait_until(:instance_terminated, instance_ids:[@instance.instance_id])
    end

    it 'that can have tags changed' do
      expect(@aws.tag_difference(@instance, @config[:tags])).to be_empty

      tags = {:created_by => 'aws-tests', :foo => 'bar'}
      @config[:tags].update(tags)

      PuppetManifest.new(@template, @config).apply
      @instance = get_instance(@config[:name])
      expect(@aws.tag_difference(@instance, @config[:tags])).to be_empty
    end

    it "that can be stopped and restarted" do
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
        :image_id => 'ami-67a60d7a',
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
      expect(['stopping', 'stopped']).to include(instance.state.name)
    end

    it 'launched as running' do
      config[:ensure] = 'running'
      r = PuppetManifest.new(@template, config).apply
      expect(r[:output].any?{ |o| o.include?('Error:')}).to eq(false)
      instance = get_instance(config[:name])
      # without a wait this will return pending due to the EC2 lifecycle
      # the test here is that we can use running as an alias, so the wait isn't breaking that
      @aws.ec2_client.wait_until(:instance_running, instance_ids: [instance.instance_id])
      instance = get_instance(config[:name])
      expect(instance.state.name).to eq('running')
    end
  end

  describe 'should create a new instance with puppet resource' do

    before(:all) do
      @config = {
        :name => "#{PuppetManifest.env_id}-#{SecureRandom.uuid}",
        :instance_type => 't1.micro',
        :region => @default_region,
        :image_id => 'ami-67a60d7a',
        :ensure => 'present',
        :monitoring => false,
        :availability_zone => @default_availability_zone,
        :security_groups => 'default',
      }

      # The value for this ENV var must be an existing key in your Amazon account
      # the key must be available in the sa-east-1 region
      @config[:key_name] = ENV['AWS_KEY_PAIR'] if ENV['AWS_KEY_PAIR']
      # create new instance with puppet resource
      TestExecutor.puppet_resource('ec2_instance', @config, '--modulepath ../')
      #wait for instance to report as running
      @instance = get_instance(@config[:name])
      @aws.ec2_client.wait_until(:instance_running, instance_ids:[@instance.instance_id])
      # set env variable and use puppet resource to inspect state of ec2 instance
      ENV['AWS_REGION'] = @config[:region]
      @result = TestExecutor.puppet_resource('ec2_instance', {:name => @config[:name]}, '--modulepath ../')
      expect(@result.stderr).not_to match(/\b/)
      # re-assign @instance for more up to date info
      @instance = get_instance(@config[:name])
    end

    after(:all) do
      @config[:ensure] = 'absent'
      TestExecutor.puppet_resource('ec2_instance', @config, '--modulepath ../')
      @aws.ec2_client.wait_until(:instance_terminated, instance_ids:[@instance.instance_id]) do |w|
        w.max_attempts = 5
      end
    end

    it 'ensure is correct' do
      regex = /(ensure)(\s*)(=>)(\s*)('running')/
      expect(@result.stdout).to match(regex)
    end

    it 'instance_type is correct' do
      regex = /(instance_type)(\s*)(=>)(\s*)('#{@config[:instance_type]}')/
      expect(@result.stdout).to match(regex)
    end

    it 'region is correct' do
      regex = /(region)(\s*)(=>)(\s*)('#{@config[:region]}')/
      expect(@result.stdout).to match(regex)
    end

    it 'image_id is correct' do
      regex = /(image_id)(\s*)(=>)(\s*)('#{@config[:image_id]}')/
      expect(@result.stdout).to match(regex)
    end

    it 'security_groups is correct' do
      regex = /(security_groups)(\s*)(=>)(\s*)(\['default'\])/
      expect(@result.stdout).to match(regex)
    end

    it 'virtualization_type is correct' do
      regex = /(virtualization_type)(\s*)(=>)(\s*)('paravirtual')/
      expect(@result.stdout).to match(regex)
    end

    it 'availability_zone is correct' do
      regex = /(availability_zone)(\s*)(=>)(\s*)('#{@config[:availability_zone]}')/
      expect(@result.stdout).to match(regex)
    end

    it 'hypervisor is correct' do
      regex = /(hypervisor)(\s*)(=>)(\s*)('xen')/
      expect(@result.stdout).to match(regex)
    end

    it 'instance_id is reported' do
      regex = /(instance_id)(\s*)(=>)(\s*)('#{@instance.instance_id}')/
      expect(@result.stdout).to match(regex)
    end

    it 'monitoring is correct' do
      regex = /(monitoring)(\s*)(=>)(\s*)('#{@config[:monitoring]}')/
      expect(@result.stdout).to match(regex)
    end

    it 'private_dns_name is reported' do
      regex = /(private_dns_name)(\s*)(=>)(\s*)('#{@instance.private_dns_name}')/
      expect(@result.stdout).to match(regex)
    end

    it 'public_dns_name is reported' do
      regex = /(public_dns_name)(\s*)(=>)(\s*)('#{@instance.public_dns_name}')/
      expect(@result.stdout).to match(regex)
    end

    it 'key_name is correct' do
      if ENV['AWS_KEY_PAIR']
        # key was supplied at creation of ec2 instance
        # key should be reported
        # we will need a key to run this with in CI
        regex = /(key_name)(\s*)(=>)(\s*)('#{@config[:key_name]}')/
        expect(@result.stdout).to match(regex)
      else
        # no key was supplied on creation of ec2 instance
        # should not report key
        regex = /key_name/
        expect(@result.stdout).not_to match(regex)
      end
    end

    it 'private_ip_address is reported' do
      regex = /(private_ip_address)(\s*)(=>)(\s*)('#{@instance.private_ip_address}')/
      expect(@result.stdout).to match(regex)
    end

    it 'public_ip_address is reported' do
      regex = /(public_ip_address)(\s*)(=>)(\s*)('#{@instance.public_ip_address}')/
      expect(@result.stdout).to match(regex)
    end

    context 'stop the instance' do

      before(:all) do
        #stop the instance
        @config[:ensure] = 'stopped'
        ENV['AWS_REGION'] = @config[:region]
        TestExecutor.puppet_resource('ec2_instance', @config, '--modulepath ../')
        @aws.ec2_client.wait_until(:instance_stopped, instance_ids:[@instance.instance_id])
        @stop_result = TestExecutor.puppet_resource('ec2_instance', {:name => @config[:name]}, '--modulepath ../')
      end

      it 'reports the instance as stopped' do
        regex = /(ensure)(\s*)(=>)(\s*)('stopped')/
        expect(@stop_result.stdout).to match(regex)
      end

    end
  end

  describe 'with a specified subnet should create a new instance' do

    before(:each) do
      @config = {
        :name => "#{PuppetManifest.env_id}-#{SecureRandom.uuid}",
        :instance_type => 't1.micro',
        :region => 'sa-east-1',
        :image_id => 'ami-67a60d7a',
        :ensure => 'present',
        :tags => {
          :department => 'engineering',
          :project    => 'cloud',
          :created_by => 'aws-acceptance'
        },
        :optional => {
          # This is currently a hardcoded, pre-existing subnet.
          # Once the VPC support is merged this test should move to the VPC
          # test suite and use a subnet created during the tests
          :subnet => 'subnet-acceptance',
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

    it "associated with a VPC" do
      expect(@instance.subnet_id).not_to be_nil
      expect(@instance.vpc_id).not_to be_nil
    end
  end

end

