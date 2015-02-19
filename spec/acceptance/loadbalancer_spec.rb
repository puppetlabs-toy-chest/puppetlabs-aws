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
          :image_id => 'ami-67a60d7a',
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
      skip('VPC only accounts will fail here')
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


  describe 'create a load balancer' do

    context 'with a manifest' do
      before(:all) do
        @instance_config = {
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

        PuppetManifest.new(@instance_template, @instance_config).apply

        @lb_config = {
          :name                 => "#{PuppetManifest.env_dns_id}#{SecureRandom.uuid}".gsub('-', '')[0...31],
          :ensure               => 'present',
          :region               => @default_region,
          :security_groups      => ['default'],
          :availability_zones   => [@default_availability_zone, "#{@default_region}b"],
          :instances            => [@instance_config[:name]],
          :listeners            => [
            {
              :protocol => 'tcp',
              :port     => 80,
            }
          ],
          :tags                 => {
              :department => 'engineering',
              :project    => 'cloud',
              :created_by => 'aws-acceptance',
              :marco      => 'polo',
          }
        }
        @lb2_template = 'loadbalancer2.pp.tmpl'
        PuppetManifest.new(@lb2_template, @lb_config).apply
      end

      context 'using puppet resource to describe' do

        before(:all) do
          @result = TestExecutor.puppet_resource('elb_loadbalancer', {:name => @lb_config[:name]}, '--modulepath ../')
        end

        it 'region' do
          regex = /(region)(\s*)(=>)(\s*)('#{@lb_config[:region]}')/
          expect(@result.stdout).to match(regex)
        end

        it 'security_groups' do
          pending('This test is blocked by CLOUD-211')
          regex = /(security_groups)(\s*)(=>)(\s*)('default')/
          expect(@result.stdout).to match(regex)
        end

        it 'availablity_zones' do
          pending('This test is blocked by CLOUD-210')
          @lb_config[:availability_zones].each do |listener, value|
            regex = /('#{listener}')(\s*)(=>)(\s*)('#{value}')/
            expect(@result.stdout).to match(regex)
          end
        end

        it 'instances' do
          pending('This test is blocked by CLOUD-209')
          @lb_config[:instances].each do |i|
            regex = /('#{i}')/
            expect(@result.stdout).to match(regex)
          end
        end

        it 'listeners' do
          pending('This test is blocked by CLOUD-208')
          # this needs to be tested once fixed
          @lb_config[:listeners].each do |l|
            r = String.new
            l.each do |k, v|
              r << "('#{k}')(\\s*)(=>)(\\s*)('#{v}')(\\s*)"
            end
            regex = /#{r}/m
            expect(result.stdout).to (regex)
          end
        end

        it 'tags' do
          pending('This test is blocked by CLOUD-207')
          @elb_config[:tags].each do |tag, value|
            regex = /('#{tag}')(\s*)(=>)(\s*)('#{value}')/
            expect(@result.stdout).to match(regex)
          end
        end

      end

      context 'destroy the load balancer' do
        before(:all) do
          ENV['AWS_REGION'] = @default_region
        end

        after(:all) do
          # destroy the EC2 instance
          @instance_config[:ensure] = 'absent'
          PuppetManifest.new(@instance_template, @instance_config).apply
        end

        it 'with puppet resource' do
          ENV['AWS_REGION'] = @default_region
          TestExecutor.puppet_resource('elb_loadbalancer', {:name => @lb_config[:name], :ensure => 'absent', :region => @default_region}, '--modulepath ../')
          expect{ get_loadbalancer(@lb_config[:name]) }.to raise_error Aws::ElasticLoadBalancing::Errors::LoadBalancerNotFound
        end

      end
    end

  end
end
