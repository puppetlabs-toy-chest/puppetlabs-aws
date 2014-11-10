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

  def has_matching_tags(instance, tags)
    instance_tags = {}
    instance.tags.each { |s| instance_tags[s.key.to_sym] = s.value if s.key != 'Name' }

    symmetric_difference = tags.to_set ^ instance_tags.to_set
    expect(symmetric_difference).to be_empty
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
      @instance = find_instance(@config[:name])
    end

    after(:all) do
      @ec2.client.wait_until(:instance_running, instance_ids:[@instance.instance_id])

      new_config = @config.update({:ensure => 'absent'})
      PuppetManifest.new(@template, new_config).apply

      @ec2.client.wait_until(:instance_terminated, instance_ids:[@instance.instance_id])
    end

    it "with the specified name" do
      expect(@instance.tags.detect { |tag| tag.key == 'Name' }.value).to eq(@config[:name])
    end

    it "with the specified tags" do
      has_matching_tags(@instance, @config[:tags])
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
        :tags => {
          :department => 'engineering',
          :project    => 'cloud',
          :created_by => 'aws-acceptance'
        }
      }

      PuppetManifest.new(@template, @config).apply
      @instance = find_instance(@config[:name])
    end

    after(:each) do
      @config[:ensure] = 'absent'
      PuppetManifest.new(@template, @config).apply

      @ec2.client.wait_until(:instance_terminated, instance_ids:[@instance.instance_id])
    end

    it 'that can have tags changed' do
      wait_until_status(@config[:name], 'running', 45)
      has_matching_tags(@instance, @config[:tags])

      tags = {:created_by => 'aws-tests', :foo => 'bar'}
      @config[:tags].update(tags)

      PuppetManifest.new(@template, @config).apply
      @instance = find_instance(@config[:name])
      has_matching_tags(@instance, @config[:tags])
    end

    it "that can be stopped and restarted" do
      @ec2.client.wait_until(:instance_running, instance_ids:[@instance.instance_id])

      @config[:ensure] = 'stopped'
      PuppetManifest.new(@template, @config).apply

      @ec2.client.wait_until(:instance_stopped, instance_ids:[@instance.instance_id])

      @config[:ensure] = 'present'
      PuppetManifest.new(@template, @config).apply
      @ec2.client.wait_until(:instance_running, instance_ids:[@instance.instance_id])
    end
  end

end
