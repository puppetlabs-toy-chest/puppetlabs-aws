require 'spec_helper_acceptance'
require 'securerandom'

describe "elb_loadbalancer" do
  before(:all) do
    @default_region = 'sa-east-1'
    @default_availability_zone = "#{@default_region}a"
    @aws = AwsHelper.new(@default_region)
    @instance_template = 'instance.pp.tmpl'
    @lb_template = 'loadbalancer.pp.tmpl'

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
      },
      :device_name => '/dev/sda1',
      :volume_size => 8,
    }

    PuppetManifest.new(@instance_template, @instance_config).apply
    instances = @aws.get_instances(@instance_config[:name])
    expect(instances.count).to eq(1)
    @instance = instances[0]
  end

  after(:all) do
    new_instance_config = @instance_config.update({:ensure => 'absent'})
    PuppetManifest.new(@instance_template, new_instance_config).apply
  end

  def get_loadbalancer(name)
    loadbalancers = @aws.get_loadbalancers(name)
    expect(loadbalancers.count).to eq(1)
    loadbalancers.first
  end

  describe 'creating a load balancer - single AZ' do
    before(:all) do
      @lb_config = {
          :name => "#{PuppetManifest.env_dns_id}#{SecureRandom.uuid}".gsub(/[^a-zA-Z0-9]/, '')[0...31], # adhere to the LB's naming restrictions
          :region => @default_region,
          :availability_zones => [@default_availability_zone],
          :instances => [@instance_config[:name]],
          :listeners => [
            {
              :protocol           => 'TCP',
              :load_balancer_port => 80,
              :instance_protocol  => 'TCP',
              :instance_port      => 80,
            }
          ],
          :ensure => 'present',
          :tags => {
              :department => 'engineering',
              :project    => 'cloud',
              :created_by => 'aws-acceptance'
          }
      }
      @result = PuppetManifest.new(@lb_template, @lb_config).apply
      @loadbalancer = get_loadbalancer(@lb_config[:name])
    end

    after(:all) do
      new_lb_config = @lb_config.update({:ensure => 'absent'})
      PuppetManifest.new(@lb_template, new_lb_config).apply
    end

    it 'should run successfully first time with changes' do
      expect(@result.exit_code).to eq(2)
    end

    it 'should run idempotently' do
      result = PuppetManifest.new(@lb_template, @lb_config).apply
      expect(result.exit_code).to eq(0)
    end

    it "with the specified name" do
      expect(@loadbalancer.load_balancer_name).to eq(@lb_config[:name])
    end

    it "with the specified availability zone" do
      expect(@loadbalancer.availability_zones).to eq(@lb_config[:availability_zones])
    end

    it "with the default scheme" do
      expect(@loadbalancer.scheme).to eq('internet-facing')
    end

    it "with one associated instance" do
      expect(@loadbalancer.instances.count).to eq(1)
    end

    context "on EC2-Classic accounts" do
      it "not part of a VPC" do
        skip "not running on EC2-Classic" if @aws.vpc_only?
        expect(@loadbalancer.vpc_id).to be_nil
        expect(@loadbalancer.subnets).to be_empty
      end

      it "with no associated security groups" do
        skip "not running on EC2-Classic" if @aws.vpc_only?
        expect(@loadbalancer.security_groups).to be_empty
      end
    end
  end

  describe 'creating a load balancer - multiple AZ' do
    context 'with a manifest' do
      before(:all) do
        @lb_config = {
          :name                 => "#{PuppetManifest.env_dns_id}#{SecureRandom.uuid}".gsub('-', '')[0...31],
          :ensure               => 'present',
          :region               => @default_region,
          :security_groups      => ['default'],
          :availability_zones   => [@default_availability_zone, "#{@default_region}b"],
          :instances            => [@instance_config[:name]],
          :listeners            => [
            {
              :protocol           => 'TCP',
              :load_balancer_port => 80,
              :instance_protocol  => 'TCP',
              :instance_port      => 80,
            }
          ],
          :tags                 => {
            :department => 'engineering',
            :project    => 'cloud',
            :created_by => 'aws-acceptance',
            :marco      => 'polo',
          }
        }
        @lb_template = 'loadbalancer.pp.tmpl'
        @result = PuppetManifest.new(@lb_template, @lb_config).apply
      end

      after(:all) do
        new_lb_config = @lb_config.update({:ensure => 'absent'})
        PuppetManifest.new(@lb_template, new_lb_config).apply
      end

      it 'should run successfully first time with changes' do
        expect(@result.exit_code).to eq(2)
      end

      it 'should run idempotently' do
        result = PuppetManifest.new(@lb_template, @lb_config).apply
        expect(result.exit_code).to eq(0)
      end

      context 'using puppet resource to describe' do
        before(:all) do
          @result = TestExecutor.puppet_resource('elb_loadbalancer', {:name => @lb_config[:name]}, '--modulepath spec/fixtures/modules/')
        end

        it 'region' do
          regex = /(region)(\s*)(=>)(\s*)('#{@lb_config[:region]}')/
          expect(@result.stdout).to match(regex)
        end

        it 'availablity_zones' do
          regex = /availability_zones\s*=>\s*\[(\'sa\-east\-1a\', \'sa\-east\-1b\'|\'sa\-east\-1b\', \'sa\-east\-1a\')\]/
          expect(@result.stdout).to match(regex)
        end

        it 'instances' do
          @lb_config[:instances].each do |i|
            regex = /('#{i}')/
            expect(@result.stdout).to match(regex)
          end
        end

        it 'listeners' do
          @lb_config[:listeners].each do |l|
            l.each do |k, v|
              regex = "('#{k}')(\\s*)(=>)(\\s*)('#{v}')(\\s*)"
              expect(@result.stdout).to match(regex)
            end
          end
        end

        it 'tags' do
          @lb_config[:tags].each do |tag, value|
            regex = /('#{tag}')(\s*)(=>)(\s*)('#{value}')/
            expect(@result.stdout).to match(regex)
          end
        end
      end
    end
  end
end
