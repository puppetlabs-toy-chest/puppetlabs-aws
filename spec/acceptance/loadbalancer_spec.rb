require 'spec_helper_acceptance'
require 'securerandom'

describe "elb_loadbalancer" do
  before(:all) do
    @default_region = 'us-east-1'
    @name = 'cc-test'
    @default_ami = 'ami-2121764b'
    @default_availability_zone = "#{@default_region}a"  
    @aws = AwsHelper.new(@default_region)
  end

  def get_loadbalancer(name)
    loadbalancers = @aws.get_loadbalancers(name)
    expect(loadbalancers.count).to eq(1)
    loadbalancers.first
  end

  describe 'create a elb load balancer and instance' do
    before(:all) do
      @instance_template = 'instance.pp.tmpl'
      @lb_template = 'loadbalancer.pp.tmpl'
      @instance_config = {
        :name => @name,
        :instance_type => 't1.micro',
        :region => @default_region,
        :image_id => @default_ami,
        :ensure => 'present',
        :tags => {
          :created_by => 'cloudandcontainers'
        },
        :device_name => '/dev/sda1',
        :volume_size => 8
      }
      @manifest = PuppetManifest.new(@instance_template, @instance_config)
      puts "#{@manifest.render}"
      @result = @manifest.apply
      @instances = @aws.get_instances(@instance_config[:name])
      @instance = @instances[0]

    end

    it 'shall run successfully' do
      expect(@result.exit_code).to equal(2)
    end

    it 'shall have started an instance' do
      expect(@instances.count).to eq(1)    
    end

    after(:all) do
      new_instance_config = @instance_config.update({:ensure => 'absent'})
      PuppetManifest.new(@instance_template, new_instance_config).apply
    end

    describe 'creating a load balancer - single AZ' do
      before(:all) do
        @lb_config = {
            :name => @name,
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
        @manifest = PuppetManifest.new(@lb_template, @lb_config)
        puts "manifest #{@manifest.render}"
        @result = @manifest.apply
        @loadbalancer = get_loadbalancer(@lb_config[:name])
      end

      it 'should run successfully first time with changes' do
        expect(@result.exit_code).to eq(2)
      end

      it 'should run idempotently' do
        result = @manifest.apply
        expect(result.exit_code).to eq(0)
      end

      it "with the specified name" do
        expect(@loadbalancer.load_balancer_name).to eq(@lb_config[:name])
      end

      it "with the specified availability zone" do
        expect(@loadbalancer.availability_zones).to contain_exactly(*@lb_config[:availability_zones])
      end

      it "with the default scheme" do
        expect(@loadbalancer.scheme).to eq('internet-facing')
      end

      it "with one associated instance" do
        expect(@loadbalancer.instances.count).to eq(1)
      end

      after(:all) do
        new_lb_config = @lb_config.update({:ensure => 'absent'})
        PuppetManifest.new(@lb_template, new_lb_config).apply
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
            :name                 => @name,
            :ensure               => 'present',
            :region               => @default_region,
            :security_groups      => ['default'],
            :availability_zones   => [@default_availability_zone, "#{@default_region}c"],
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
              :created_by => 'cloudandcontainers',
              :marco      => 'polo',
            }
          }
          @lb_template = 'loadbalancer.pp.tmpl'
          @manifest = PuppetManifest.new(@lb_template, @lb_config)
          puts "manfiest #{@manifest.render}"
          @result = @manifest.apply
        end

        it 'should run successfully first time with changes' do
          expect(@result.exit_code).to eq(2)
        end

        it 'should run idempotently' do
          result = PuppetManifest.new(@lb_template, @lb_config).apply
          expect(result.exit_code).to eq(0)
        end

        after(:all) do
          new_lb_config = @lb_config.update({:ensure => 'absent'})
          PuppetManifest.new(@lb_template, new_lb_config).apply
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
            regex = /availability_zones\s*=>\s*\[(\'us\-east\-1a\', \'us\-east\-1c\')\]/
            expect(@result.stdout).to match(regex)
          end

          it 'instances' do
            @lb_config[:instances].each do |i|
              regex = /('#{i}')/
              expect(@result.stdout).to match(regex)
            end
          end

          it 'listeners' do
            expect(@lb_config[:listeners][0][:protocol]).to eq('TCP')
            expect(@lb_config[:listeners][0][:load_balancer_port]).to eq(80)
            expect(@lb_config[:listeners][0][:instance_protocol]).to eq('TCP')
            expect(@lb_config[:listeners][0][:instance_port]).to eq(80)
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
end
