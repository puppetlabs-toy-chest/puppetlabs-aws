require 'spec_helper_acceptance'
require 'securerandom'

describe "The AWS module" do

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

  def generate_ip
    # This generates a resolvable IP address within
    # a specific well populated range
    ip = "173.255.197.#{rand(255)}"
    begin
      Resolv.new.getname(ip)
      ip
    rescue
      generate_ip
    end
  end

  describe 'when creating a new VPC environment' do

    before(:all) do
      @name = "#{PuppetManifest.env_id}-#{SecureRandom.uuid}"
      region = 'sa-east-1'
      @config = {
        :name => @name,
        :region => region,
        :ensure => 'present',
        :netbios_node_type => 2,
        :vpc_cidr => '10.0.0.0/16',
        :vpc_instance_tenancy => 'default',
        :subnet_cidr => '10.0.0.0/24',
        :subnet_availability_zone => "#{region}a",
        :vpn_type => 'ipsec.1',
        :customer_ip_address => generate_ip,
        :bgp_asn => '65000',
        :vpn_route => '0.0.0.0/0',
        :static_routes => true,
        :tags => {
          :department => 'engineering',
          :project => 'cloud',
          :created_by => 'aws-acceptance',
        },
      }

      @template = 'vpc.pp.tmpl'
      @exit = PuppetManifest.new(@template, @config).apply[:exit_status]

      @vpc = find_vpc("#{@name}-vpc")
      @option = find_dhcp_option("#{@name}-options")
      @subnet = find_subnet("#{@name}-subnet")
      @vgw = find_vpn_gateway("#{@name}-vgw")
      @cgw = find_customer_gateway("#{@name}-cgw")
    end

    after(:all) do
      new_config = @config.update({:ensure => 'absent'})
      template = 'vpc_delete.pp.tmpl'
      PuppetManifest.new(template, new_config).apply
    end

    it 'should run successfully first time with changes' do
      expect(@exit.exitstatus).to eq(2)
    end

    it 'should run idempotently' do
      success = PuppetManifest.new(@template, @config).apply[:exit_status].success?
      expect(success).to eq(true)
    end

    it 'should create a VPC' do
      expect(@vpc).not_to be_nil
      expect(@vpc.instance_tenancy).to eq(@config[:vpc_instance_tenancy])
      expect(@vpc.cidr_block).to eq(@config[:vpc_cidr])
      expect(@vpc.dhcp_options_id).to eq(@option.dhcp_options_id)
    end

    it 'should create a DHCP option set' do
      node_type = @option.dhcp_configurations.find { |conf| conf.key == 'netbios-node-type' }
      expect(@option).not_to be_nil
      expect(node_type.values.first.value.to_i).to eq(@config[:netbios_node_type])
      expect(@aws.tag_difference(@option, @config[:tags])).to be_empty
    end

    it 'should create a route table' do
      table = find_route_table("#{@name}-routes")
      expect(table).not_to be_nil
      expect(table.vpc_id).to eq(@vpc.vpc_id)
      expect(table.associations.size).to eq(1)
      expect(table.associations.first.subnet_id).to eq(@subnet.subnet_id)
      expect(@aws.tag_difference(table, @config[:tags])).to be_empty
    end

    it 'should create a subnet' do
      expect(@subnet).not_to be_nil
      expect(@subnet.vpc_id).to eq(@vpc.vpc_id)
      expect(@subnet.cidr_block).to eq(@config[:subnet_cidr])
      expect(@subnet.availability_zone).to eq(@config[:subnet_availability_zone])
      expect(@subnet.map_public_ip_on_launch).to be_falsy
      expect(@subnet.default_for_az).to be_falsy
      expect(@aws.tag_difference(@subnet, @config[:tags])).to be_empty
    end

    it 'should create a VPN gateway' do
      expect(@vgw.type).to eq(@config[:vpn_type])
      expect(@vgw.vpc_attachments.size).to eq(1)
      expect(@vgw.vpc_attachments.first.vpc_id).to eq(@vpc.vpc_id)
      expect(@vgw.availability_zone).to be_nil
      expect(@aws.tag_difference(@vgw, @config[:tags])).to be_empty
    end

    it 'should create an internet gateway' do
      igw = find_internet_gateway("#{@name}-igw")
      expect(igw.attachments.size).to eq(1)
      expect(igw.attachments.first.vpc_id).to eq(@vpc.vpc_id)
      expect(@aws.tag_difference(igw, @config[:tags])).to be_empty
    end

    it 'should create an customer gateway' do
      expect(@cgw.type).to eq(@config[:vpn_type])
      expect(@cgw.ip_address).to eq(@config[:customer_ip_address])
      expect(@cgw.bgp_asn).to eq(@config[:bgp_asn])
      expect(@aws.tag_difference(@cgw, @config[:tags])).to be_empty
    end

    it 'should create a VPN' do
      vpn = find_vpn("#{@name}-vpn")
      expect(vpn.type).to eq(@config[:vpn_type])
      expect(vpn.vpn_gateway_id).to eq(@vgw.vpn_gateway_id)
      expect(vpn.customer_gateway_id).to eq(@cgw.customer_gateway_id)
      expect(vpn.routes.size).to eq(1)
      expect(vpn.routes.first.destination_cidr_block).to eq(@config[:vpn_route])
      expect(vpn.options.static_routes_only).to eq(@config[:static_routes])
      expect(@aws.tag_difference(vpn, @config[:tags])).to be_empty
    end

    it 'should allow tags to be changed' do
      expect(@aws.tag_difference(@vpc, @config[:tags])).to be_empty
      tags = {
        :department => 'engineering',
        :created_by => 'aws-acceptance',
        :foo => 'bar',
      }
      new_config = @config.dup.update(tags)
      PuppetManifest.new(@template, new_config).apply
      vpc = find_vpc("#{@name}-vpc")
      expect(@aws.tag_difference(vpc, new_config[:tags])).to be_empty
    end

    describe 'using puppet resource on the VPC' do
      before(:all) do
        ENV['AWS_REGION'] = @default_region
        options = {:name => "#{@name}-vpc"}
        @result = TestExecutor.puppet_resource('ec2_vpc', options, '--modulepath ../')
      end

      it 'should show the correct tenancy' do
        regex = /instance_tenancy\s*=>\s*'#{@config[:vpc_instance_tenancy]}'/
        expect(@result.stdout).to match(regex)
      end

      it 'should show the correct cidr block' do
        regex = /cidr_block\s*=>\s*'#{Regexp.quote(@config[:vpc_cidr])}'/
        expect(@result.stdout).to match(regex)
      end

      it 'should show the correct region' do
        regex = /region\s*=>\s*'#{@config[:region]}'/
        expect(@result.stdout).to match(regex)
      end
    end

  end

end
