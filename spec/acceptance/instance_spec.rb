require 'spec_helper_acceptance'
require 'securerandom'

describe "ec2_instance" do

  before(:all) do
    @default_region = 'sa-east-1'
    @ec2 = Ec2Helper.new(@default_region)
    @template = 'instance.pp.tmpl'
  end

  def find_instance(name)
    instances = @ec2.get_instances(name)
    expect(instances.count).to eq(1)
    instances.first
  end

  def wait_until_status(name, status, max_wait = 15)
    slept = 0

    loop do
      current_status = find_instance(name).state.name
      break if current_status == status

      sleep(1)
      slept += 1

      if slept > max_wait
        msg = "Exceeded timeout of #{max_wait} waiting for #{name} to be #{status}"
        expect(current_status).to eq(status), msg
      end
    end
  end

  describe 'should create a new instance' do

    before(:all) do
      @config = {
        :name => "#{PuppetManifest.env_id}-#{SecureRandom.uuid}",
        :instance_type => 't1.micro',
        :region => @default_region,
        :image_id => 'ami-41e85d5c',
        :ensure => 'present',
      }

      PuppetManifest.new(@template, @config).apply
      @instance = find_instance(@config[:name])
    end

    after(:all) do
      wait_until_status(@config[:name], 'running')

      new_config = @config.update({:ensure => 'absent'})
      PuppetManifest.new(@template, new_config).apply

      wait_until_status(@config[:name], 'shutting-down')
    end

    it "with the specified name" do
      expect(@instance.tags.detect { |tag| tag.key == 'Name' }.value).to eq(@config[:name])
    end

    it "with the specified type" do
      expect(@instance.instance_type).to eq(@config[:instance_type])
    end

    it "with the specified AMI" do
      expect(@instance.image_id).to eq(@config[:image_id])
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
      }

      PuppetManifest.new(@template, @config).apply
      @instance = find_instance(@config[:name])
    end

    after(:each) do
      @config[:ensure] = 'absent'
      PuppetManifest.new(@template, @config).apply

      wait_until_status(@config[:name], 'shutting-down')
    end

    it "that can be stopped and restarted" do
      wait_until_status(@config[:name], 'running', 45)

      @config[:ensure] = 'stopped'
      PuppetManifest.new(@template, @config).apply

      wait_until_status(@config[:name], 'stopped', 120)

      @config[:ensure] = 'present'
      PuppetManifest.new(@template, @config).apply

      wait_until_status(@config[:name], 'running', 30)
    end
  end

end
