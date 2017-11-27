require 'spec_helper_acceptance'
require 'securerandom'
require 'Resolv'

describe "The AWS module" do
  before(:all) do
    @default_region = 'us-east-1'
    @name = "cc-test"    
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

  def find_instance(name)
    finder(name, 'get_instances')
  end

  def find_security_group(name)
    group_response = @aws.ec2_client.describe_security_groups(filters: [
      {name: 'group-name', values: [name]}
    ])
    items = group_response.data.security_groups
    expect(items.count).to eq(1)
    items.first
  end

  def generate_ip
    # This generates a resolvable IP address within
    # a specific well populated range
    ip = "173.255.197.#{rand(255)}"
    subnet=0
    while subnet < 256 do
      begin
        Resolv.new.getname(ip)
        break
      rescue Exception => e
        puts "DNS name resolution failed on ip [#{ip}] #{e}"
      end
      subnet = subnet + 1
    end
    raise "Failed to generate a resolvable address in the range 173.255.197.0/24" unless subnet < 256
    ip
  end

  
  describe 'deleting all types with puppet resource' do
    before(:all) do
      ip_address = generate_ip
      @delete_me = {
        # shared properties
        :name                       => @name,
        :region                     => @default_region,
        :ensure                     => 'present',
        :tags                       => {
          :created_by     => 'cloudandcontainers',
        },
        :vpn_type                   => 'ipsec.1',
        # ec2_vpc properties
        :vpc_cidr                   => '10.0.0.0/16',
        :dhcp_options_setting       => "#{@name}-options",
        :vpc_instance_tenancy       => 'default',
        # ec2_vpc_dhcp_options properties
        :netbios_node_type          => 2,
        :netbios_name_servers       => ['172.16.48.16', '172.16.48.32','172.16.48.48'],
        :ntp_servers                => ['172.16.32.16', '172.16.32.32','172.16.32.48'],
        :domain_name_servers        => ['172.16.16.16', '172.16.16.32','172.16.16.48'],
        :domain_name                => ['example.com', 'example2.com', 'example3.com'],
        # ec2_vpc_routetable properties
        :routetable_vpc_setting     => "#{@name}-vpc",
        :route_settings             => [
          {
            # igw
            :destination_cidr_block => '10.50.50.50/31',
            :gateway                => "#{@name}-igw",
          },
          {
            # vgw
            :destination_cidr_block => '10.20.20.20/30',
            :gateway                => "#{@name}-vgw",
          },
          {
            :destination_cidr_block => '10.0.0.0/16',
            :gateway                => 'local',
          },
        ],
        # ec2_vpc_subnet properties
        :subnet_vpc_setting         => "#{@name}-vpc",
        :subnet_cidr                => '10.0.0.0/24',
        :subnet_availability_zone   => "#{@default_region}a",
        :subnet_route_table_setting => "#{@name}-routes",
        # ec2_vpc_internet_gateway properties
        :igw_vpc_setting            => "#{@name}-vpc",
        # ec2_vpc_customer_gateway properties
        :customer_ip_address        => ip_address,
        :bgp_asn                    => '65000',
        # ec2_vpc_vpn properties
        :vpn_vgw_setting            => "#{@name}-vgw",
        :vpn_cgw_setting            => "#{@name}-cgw",
        :vpn_routes                 => ['0.0.0.0/0', '0.0.0.50/31'],
        :static_routes              => true,
        # ec2_vpc_vpn_gateway properites
        :vgw_vpc_setting            => "#{@name}-vpc",
        :vgw_availability_zone      => "#{@default_region}a",
        :associate_public_ip_address => false,
      }
      template = 'vpc_complete.pp.tmpl'
      result = PuppetManifest.new(template, @delete_me).apply
      expect(result.stderr).not_to match(/error/i)
    end

    it 'should delete without error' do
      # These types must be deleted in order
      ENV['AWS_REGION'] = @default_region
      error_message = 'An unexpected error was raised with puppet resource'
      # instance
      instance_name = "#{@delete_me[:name]}-instance"
      options = {:name => instance_name, :region => @default_region, :ensure => 'absent'}
      result = TestExecutor.puppet_resource('ec2_instance', options, '--modulepath spec/fixtures/modules/')
      expect(result.stderr).not_to match(/Error/), error_message
      expect(@aws.send('get_terminated_instances', instance_name).first.state.name).to eq('terminated')
      # igw
      igw_name = "#{@delete_me[:name]}-igw"
      options = {:name => igw_name, :region => @default_region, :ensure => 'absent'}
      result = TestExecutor.puppet_resource('ec2_vpc_internet_gateway', options, '--modulepath spec/fixtures/modules/')
      expect(result.stderr).not_to match(/Error/), error_message
      expect(@aws.send('get_vpn_gateways', igw_name)).to be_empty
      # vpn
      vpn_name = "#{@delete_me[:name]}-vpn"
      options = {:name => vpn_name, :region => @default_region, :ensure => 'absent'}
      result = TestExecutor.puppet_resource('ec2_vpc_vpn', options, '--modulepath spec/fixtures/modules/')
      expect(result.stderr).not_to match(/Error/), error_message
      expect(@aws.send('get_vpn', vpn_name)).to be_empty
      # cgw
      cgw_name = "#{@delete_me[:name]}-cgw"
      options = {:name => cgw_name, :region => @default_region, :ensure => 'absent'}
      result = TestExecutor.puppet_resource('ec2_vpc_customer_gateway', options, '--modulepath spec/fixtures/modules/')
      expect(result.stderr).not_to match(/Error/), error_message
      expect(@aws.send('get_customer_gateways', cgw_name)).to be_empty
      # vpn gateway
      vgw_name = "#{@delete_me[:name]}-vgw"
      options = {:name => vgw_name, :region => @default_region, :ensure => 'absent'}
      result = TestExecutor.puppet_resource('ec2_vpc_vpn_gateway', options, '--modulepath spec/fixtures/modules/')
      expect(result.stderr).not_to match(/Error/), error_message
      expect(@aws.send('get_vpn_gateways', vgw_name)).to be_empty
      # subnet
      subnet_name = "#{@delete_me[:name]}-subnet"
      options = {:name => subnet_name, :region => @default_region, :ensure => 'absent'}
      result = TestExecutor.puppet_resource('ec2_vpc_subnet', options, '--modulepath spec/fixtures/modules/')
      expect(result.stderr).not_to match(/Error/), error_message
      expect(@aws.send('get_subnets', subnet_name)).to be_empty
      # routes
      routes_name = "#{@delete_me[:name]}-routes"
      options = {:name => routes_name, :region => @default_region, :ensure => 'absent'}
      result = TestExecutor.puppet_resource('ec2_vpc_routetable', options, '--modulepath spec/fixtures/modules/')
      expect(result.stderr).not_to match(/Error/), error_message
      expect(@aws.send('get_route_tables', routes_name)).to be_empty
      # vpc
      vpc_name = "#{@delete_me[:name]}-vpc"
      options = {:name => vpc_name, :region => @default_region, :ensure => 'absent'}
      result = TestExecutor.puppet_resource('ec2_vpc', options, '--modulepath spec/fixtures/modules/')
      expect(result.stderr).not_to match(/Error/), error_message
      expect(@aws.send('get_vpcs', vpc_name)).to be_empty
      # dhcp options
      options_name = "#{@delete_me[:name]}-options"
      options = {:name => options_name, :region => @default_region, :ensure => 'absent'}
      result = TestExecutor.puppet_resource('ec2_vpc_dhcp_options', options, '--modulepath spec/fixtures/modules/')
      expect(result.stderr).not_to match(/Error/), error_message
      expect(@aws.send('get_dhcp_options', options_name)).to be_empty
    end
  end
end
