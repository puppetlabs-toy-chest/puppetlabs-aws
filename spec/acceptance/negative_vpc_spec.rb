require 'spec_helper_acceptance'
require 'securerandom'
require 'retries'
require 'resolv'

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

  include_context 'cleanse AWS resources for the test'

  describe 'Negative cases for VPC' do
    before(:all) do
      @template = 'vpc_complete.pp.tmpl'
      ip_address = generate_ip
      @negative_config = {
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
        :subnet_vpc_setting          => "#{@name}-vpc",
        :subnet_cidr                 => '10.0.0.0/24',
        :subnet_availability_zone    => "#{@default_region}a",
        :subnet_route_table_setting  => "#{@name}-routes",
        # ec2_vpc_internet_gateway properties
        :igw_vpc_setting             => "#{@name}-vpc",
        # ec2_vpc_customer_gateway properties
        :customer_ip_address         => ip_address,
        :bgp_asn                     => '65000',
        # ec2_vpc_vpn properties
        :vpn_vgw_setting             => "#{@name}-vgw",
        :vpn_cgw_setting             => "#{@name}-cgw",
        :vpn_routes                  => ['0.0.0.0/0', '0.0.0.50/31'],
        :static_routes               => true,
        # ec2_vpc_vpn_gateway properites
        :vgw_vpc_setting             => "#{@name}-vpc",
        :vgw_availability_zone       => "#{@default_region}a",
        :associate_public_ip_address => false,
      }
    end

    it 'attempt to add two routes that point to the same gateway' do
      @negative_config[:route_settings] = [
        {
          :destination_cidr_block => '10.50.50.50/31',
          :gateway                => "local",
        },
        {
          :destination_cidr_block => '10.20.20.20/30',
          :gateway                => "local",
        },
        {
          :destination_cidr_block => '10.0.0.0/16',
          :gateway                => 'local',
        },
      ]
      manifest = PuppetManifest.new(@template, @negative_config)
      puts "Manifest #{manifest.render}"
      result = manifest.apply
      expect(result.stderr).to match(/only one route per gateway allowed/i)
    end

    it 'attempt to add a route that has an invalid CIDR block, AWS will coerce to a valid CIDR' do
      @negative_config[:route_settings] = [
        {
          # this is the bad one
          :destination_cidr_block => '10.113.0.0/14',
          :gateway                => "#{@negative_config[:name]}-igw",
        },
        {
          :destination_cidr_block => '10.20.20.20/30',
          :gateway                => "#{@negative_config[:name]}-vgw",
        },
        {
          :destination_cidr_block => '10.0.0.0/16',
          :gateway                => 'local',
        },
      ]
      # apply once expect no error
      result = PuppetManifest.new(@template, @negative_config).apply
      expect(result.stderr).not_to match(/error/i)
      # apply again looking for puppet error on attempted change
      result2 = PuppetManifest.new(@template, @negative_config).apply
      regex = /Warning: routes property is read-only once ec2_vpc_routetable created/
      expect(result2.stderr).to match(regex)
    end
  end
  
  # include_context 'cleanse AWS resources for the test'  
end
