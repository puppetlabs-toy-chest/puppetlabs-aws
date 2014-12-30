require 'spec_helper_acceptance'
require 'securerandom'

describe "ec2_loadbalancer" do

  before(:all) do
    @default_region = 'sa-east-1'
    @default_availability_zone = "#{@default_region}a"
    @aws = AwsHelper.new(@default_region)
    @instance_template = 'instance.pp.tmpl'
    @lb_template = 'loadbalancer.pp.tmpl'
  end

  def get_loadbalancer(name)
    loadbalancers = @aws.get_loadbalancers(name)
    expect(loadbalancers.count).to eq(1)
    loadbalancers.first
  end

  describe 'should create a new load balancer' do

    before(:all) do
      @instance_config = {
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

      PuppetManifest.new(@instance_template, @instance_config).apply
      instances = @aws.get_instances(@instance_config[:name])
      expect(instances.count).to eq(1)
      @instance = instances.first

      @lb_config = {
          :name => "#{PuppetManifest.env_dns_id}#{SecureRandom.uuid}".gsub('-', '')[0...31], # loadbalancer has name length limit
          :region => @default_region,
          :availability_zones => [@default_availability_zone],
          :instances => [@instance_config[:name]],
          :listeners => [],
          :ensure => 'present',
          :tags => {
              :department => 'engineering',
              :project    => 'cloud',
              :created_by => 'aws-acceptance'
          }
      }
      PuppetManifest.new(@lb_template, @lb_config).apply
      @loadbalancer = get_loadbalancer(@lb_config[:name])
    end

    after(:all) do
      new_instance_config = @instance_config.update({:ensure => 'absent'})
      PuppetManifest.new(@instance_template, new_instance_config).apply

      new_lb_config = @lb_config.update({:ensure => 'absent'})
      PuppetManifest.new(@lb_template, new_lb_config).apply
    end

    it "with the specified name" do
      expect(@loadbalancer.load_balancer_name).to eq(@lb_config[:name])
    end

    it "with the specified availability zone" do
      expect(@loadbalancer.availability_zones).to eq(@lb_config[:availability_zones])
    end

    it "not part of a VPC" do
      expect(@loadbalancer.vpc_id).to be_nil
      expect(@loadbalancer.subnets).to be_empty
    end

    it "with one associated instance" do
      expect(@loadbalancer.instances.count).to eq(1)
    end

    it "with no associated security groups" do
      expect(@loadbalancer.security_groups).to be_empty
    end

  end
end
