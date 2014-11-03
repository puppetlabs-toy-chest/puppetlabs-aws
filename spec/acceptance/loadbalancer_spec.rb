require 'spec_helper_acceptance'
require 'securerandom'

describe "ec2_loadbalancer" do

  before(:all) do
    @default_region = 'sa-east-1'
    @default_availability_zone = "#{@default_region}a"
    @ec2 = Ec2Helper.new(@default_region)
    @template = 'loadbalancer.pp.tmpl'
  end

  def find_loadbalancer(name)
    loadbalancers = @ec2.get_loadbalancers(name)
    expect(loadbalancers.count).to eq(1)
    loadbalancers.first
  end

  describe 'should create a new load balancer' do

    before(:all) do
      @config = {
        :name => "#{SecureRandom.uuid.gsub('-', '')}"[0...31], # loadbalancer has name length limit
        :region => @default_region,
        :availability_zones => [@default_availability_zone],
        :instances => [],
        :listeners => [],
        :ensure => 'present',
        :tags => {
          :department => 'engineering',
          :project    => 'cloud',
          :created_by => 'aws-acceptance'
        }
      }
      PuppetManifest.new(@template, @config).apply

      @loadbalancer = find_loadbalancer(@config[:name])
    end

    after(:all) do
      new_config = @config.update({:ensure => 'absent'})
      PuppetManifest.new(@template, new_config).apply
    end

    it "with the specified name" do
      expect(@loadbalancer.load_balancer_name).to eq(@config[:name])
    end

    it "with the specified availability zone" do
      expect(@loadbalancer.availability_zones).to eq(@config[:availability_zones])
    end

    it "not part of a VPC" do
      expect(@loadbalancer.vpc_id).to be_nil
      expect(@loadbalancer.subnets).to be_empty
    end

    it "with no associated instances" do
      expect(@loadbalancer.instances).to be_empty
    end

    it "with no associated security groups" do
      expect(@loadbalancer.security_groups).to be_empty
    end

  end

end
