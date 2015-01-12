require 'spec_helper_acceptance'
require 'securerandom'

describe "ec2_vpc" do

  before(:all) do
    @default_region = 'sa-east-1'
    @aws = AwsHelper.new(@default_region)
  end

  def finder(name, method)
    items = @aws.send(method, name)
    expect(items.count).to eq(1)
    items.first
  end

  def find_vpc(name)
    finder(name, 'get_vpcs')
  end

  def find_dhcp_option(name)
    finder(name, 'get_dhcp_options')
  end

  def find_route_table(name)
    finder(name, 'get_route_tables')
  end

  def find_subnet(name)
    finder(name, 'get_subnets')
  end

  def find_vpn_gateway(name)
    finder(name, 'get_vpn_gateways')
  end

  def find_internet_gateway(name)
    finder(name, 'get_internet_gateways')
  end

  def find_customer_gateway(name)
    finder(name, 'get_customer_gateways')
  end

  def find_vpn(name)
    finder(name, 'get_vpn')
  end

  describe 'should create a new VPC environment' do

    before(:all) do
      @name = "#{PuppetManifest.env_id}-#{SecureRandom.uuid}"
      @config = {
        :name => @name,
        :ensure => 'present',
      }

      template = 'vpc.pp.tmpl'
      @exit = PuppetManifest.new(template, @config).apply[:exit_status]
    end

    after(:all) do
      new_config = @config.update({:ensure => 'absent'})
      template = 'vpc_delete.pp.tmpl'
      PuppetManifest.new(template, new_config).apply
    end

    it 'should run successfully with changes' do
      expect(@exit.exitstatus).to eq(2)
    end

    it 'should create a VPC' do
      find_vpc("#{@name}-vpc")
    end

    it 'should create a DHCP option set' do
      find_dhcp_option("#{@name}-options")
    end

    it 'should create a route table' do
      find_route_table("#{@name}-routes")
    end

    it 'should create a subnet' do
      find_subnet("#{@name}-subnet")
    end

    it 'should create a VPN gateway' do
      find_vpn_gateway("#{@name}-vgw")
    end

    it 'should create an internet gateway' do
      find_internet_gateway("#{@name}-igw")
    end

    it 'should create an customer gateway' do
      find_customer_gateway("#{@name}-cgw")
    end

    it 'should create a VPN' do
      find_vpn("#{@name}-vpn")
    end

  end

end
