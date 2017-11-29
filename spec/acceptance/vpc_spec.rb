require 'spec_helper_acceptance'
require 'securerandom'
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

  def find_load_balancer(name)
    finder(name, 'get_loadbalancers')
  end

  def generate_ip
    # This generates a resolvable IP address within
    # a specific well populated range
    ip = "173.255.197.#{rand(255)}"
    subnet=0
    while subnet < 256 do
      begin
        Resolv::DNS.new.getname(ip)
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
  
  describe 'when creating a new VPC environment' do
    before(:all) do
      @config = {
        :name => @name,
        :lb_name => "#{@name}-lb", # loadbalancer has name length limit
        :region => @default_region,
        :ensure => 'present',
        :netbios_node_type => 2,
        :vpc_cidr => '10.0.0.0/16',
        :vpc_instance_tenancy => 'default',
        :subnet_cidr => '10.0.0.0/24',
        :subnet_availability_zone => "#{@default_region}a",
        :map_public_ip_on_launch => false,
        :vpn_type => 'ipsec.1',
        :customer_ip_address => generate_ip,
        :bgp_asn => '65000',
        :vpn_route => '0.0.0.0/0',
        :static_routes => true,
        :security_group_ingress => [{
          :protocol => 'tcp',
          :port     => 22,
          :cidr     => '0.0.0.0/0'
        }],
        :lb_scheme => 'internal',
        :tags => {
          :name => 'default',
          :created_by => 'cloudandcontainers'
        },
      }

      @template = 'vpc.pp.tmpl'
      @manifest = PuppetManifest.new(@template, @config)
      puts "manifest #{@manifest.render}"
      @result = @manifest.apply
      @vpc = find_vpc("#{@name}-vpc")
      @dhcp_option = find_dhcp_option("#{@name}-options")
      @subnet = find_subnet("#{@name}-subnet")
      @vgw = find_vpn_gateway("#{@name}-vgw")
      @cgw = find_customer_gateway("#{@name}-cgw")
    end
    

    it 'should run successfully first time with changes' do
      expect(@result.exit_code).to eq(2)
    end

    # it 'should run idempotently' do
    #   result = PuppetManifest.new(@template, @config).apply
    #   puts "idempotent manifest #{@manifest.render}"
    #   expect(result.exit_code).to eq(0)
    # end

    describe 'the created VPC' do
      let(:subject) { @vpc }
      it { is_expected.not_to be_nil }
      it do
        is_expected.to have_attributes(
          :instance_tenancy => @config[:vpc_instance_tenancy],
          :cidr_block => @config[:vpc_cidr],
          :dhcp_options_id => @dhcp_option.dhcp_options_id,
        )
      end
    end

    describe 'the created DHCP option set' do
      it("should exist") { expect(@dhcp_option).not_to be_nil }
      it("should have the requested tags") { expect(@aws.tag_difference(@dhcp_option, @config[:tags])).to be_empty }
      it "should be of netbios-node-type" do
        netbios_node_type = @dhcp_option.dhcp_configurations.find { |conf| conf.key == 'netbios-node-type' }.values.first.value.to_i
        expect(netbios_node_type).to eq(@config[:netbios_node_type])
      end
    end

    describe 'the created security group' do
      before(:all) { @sg = find_security_group("#{@name}-sg") }
      let(:subject) { @sg }
      it { is_expected.not_to be_nil }
      it do
        is_expected.to have_attributes(
          :vpc_id => @vpc.vpc_id,
        )
      end
      it("should have the requested tags") { expect(@aws.tag_difference(@sg, @config[:tags])).to be_empty }
    end

    describe 'the created route table' do
      before(:all) { @table = find_route_table("#{@name}-routes") }
      let(:subject) { @table }
      it { is_expected.not_to be_nil }
      it do
        is_expected.to have_attributes(
          :vpc_id => @vpc.vpc_id,
        )
      end
      it("should be attached exactly one subnet") { expect(@table.associations.size).to eq(1) }
      it("should be attached to the right subnet") { expect(@table.associations.first.subnet_id).to eq(@subnet.subnet_id) }
      it("should have the requested tags") { expect(@aws.tag_difference(@table, @config[:tags])).to be_empty }
    end

    describe 'the created subnet' do
      let(:subject) { @subnet }
      it { is_expected.not_to be_nil }
      it do
        is_expected.to have_attributes(
          :vpc_id => @vpc.vpc_id,
          :cidr_block => @config[:subnet_cidr],
          :availability_zone => @config[:subnet_availability_zone],
          :map_public_ip_on_launch => @config[:map_public_ip_on_launch],
          :default_for_az => false,
        )
      end
      it("should have the requested tags") { expect(@aws.tag_difference(@subnet, @config[:tags])).to be_empty }
    end

    describe 'the created route table' do
      before(:all) { @table = find_route_table("#{@name}-routes") }
      let(:subject) { @table }
      it { is_expected.not_to be_nil }
      it do
        is_expected.to have_attributes(
          :vpc_id => @vpc.vpc_id,
        )
      end
      it("should be attached exactly one subnet") { expect(@table.associations.size).to eq(1) }
      it("should be attached to the right subnet") { expect(@table.associations.first.subnet_id).to eq(@subnet.subnet_id) }
      it("should have the requested tags") { expect(@aws.tag_difference(@table, @config[:tags])).to be_empty }
    end

    describe 'the created subnet' do
      let(:subject) { @subnet }
      it { is_expected.not_to be_nil }
      it do
        is_expected.to have_attributes(
          :vpc_id => @vpc.vpc_id,
          :cidr_block => @config[:subnet_cidr],
          :availability_zone => @config[:subnet_availability_zone],
          :map_public_ip_on_launch => @config[:map_public_ip_on_launch],
          :default_for_az => false,
        )
      end
      it("should have the requested tags") { expect(@aws.tag_difference(@subnet, @config[:tags])).to be_empty }
    end

    describe 'the created load balancer' do
      before(:all) { @lb = find_load_balancer(@config[:lb_name]) }
      let(:subject) { @lb }
      it { is_expected.not_to be_nil }
      it do
        is_expected.to have_attributes(
          :vpc_id => @vpc.vpc_id,
          :subnets => [@subnet.subnet_id],
          :availability_zones => [@config[:subnet_availability_zone]],
          :scheme => @config[:lb_scheme],
        )
      end
      it("should have exactly one instance") { expect(@lb.instances.size).to eq(1) }
      it("should have security groups") { expect(@lb.security_groups).not_to be_empty }
    end

    describe 'the created VPN gateway' do
      let(:subject) { @vgw }
      it { is_expected.not_to be_nil }
      it do
        is_expected.to have_attributes(
          :type => @config[:vpn_type],
          :availability_zone => nil,
        )
      end

      it("should be attached exactly one VPC") { expect(@vgw.vpc_attachments.size).to eq(1) }
      it("should be attached to the right VPC") { expect(@vgw.vpc_attachments.first.vpc_id).to eq(@vpc.vpc_id) }
      it("should have the requested tags") { expect(@aws.tag_difference(@vgw, @config[:tags])).to be_empty }
    end

    describe 'the created internet gateway' do
      before(:all) { @igw = find_internet_gateway("#{@name}-igw") }
      let(:subject) { @igw }
      it { is_expected.not_to be_nil }
      it("should be attached exactly one VPC") { expect(@igw.attachments.size).to eq(1) }
      it("should be attached to the right VPC") { expect(@igw.attachments.first.vpc_id).to eq(@vpc.vpc_id) }
      it("should have the requested tags") { expect(@aws.tag_difference(@igw, @config[:tags])).to be_empty }
    end

    describe 'the created customer gateway' do
      let(:subject) { @cgw }
      it { is_expected.not_to be_nil }
      it do
        is_expected.to have_attributes(
          :type => @config[:vpn_type],
          :ip_address => @config[:customer_ip_address],
          :bgp_asn => @config[:bgp_asn],
        )
      end
      it("should have the requested tags") { expect(@aws.tag_difference(@cgw, @config[:tags])).to be_empty }
    end

    describe 'the created VPN' do
      before(:all) { @vpn = find_vpn("#{@name}-vpn") }
      let(:subject) { @vpn }
      it { is_expected.not_to be_nil }
      it do
        is_expected.to have_attributes(
          :type => @config[:vpn_type],
          :vpn_gateway_id => @vgw.vpn_gateway_id,
          :customer_gateway_id => @cgw.customer_gateway_id,
        )
      end
      it("should have exactly one route") { expect(@vpn.routes.size).to eq(1) }
      it("should have the right route") { expect(@vpn.routes.first.destination_cidr_block).to eq(@config[:vpn_route]) }
      it("should be configured with static routes") { expect(@vpn.options.static_routes_only).to eq(@config[:static_routes]) }
      it("should have the requested tags") { expect(@aws.tag_difference(@vpn, @config[:tags])).to be_empty }
    end

    context 'when changing tags' do
      before(:all) do
        @new_config = @config.dup.update({
          :department => 'engineering',
          :created_by => 'aws-acceptance',
          :foo => 'bar',
        })
        PuppetManifest.new(@template, @new_config).apply
      end

      it 'on the ec2_vpc' do
        vpc = find_vpc("#{@name}-vpc")
        expect(@aws.tag_difference(vpc, @new_config[:tags])).to be_empty
      end

      it 'on the ec2_vpc_dhcp_options' do
        options = find_dhcp_option("#{@name}-options")
        expect(@aws.tag_difference(options, @new_config[:tags])).to be_empty
      end

      it 'on the ec2_vpc_routetable' do
        routetable = find_route_table("#{@name}-routes")
        expect(@aws.tag_difference(routetable, @new_config[:tags])).to be_empty
      end

      it 'on the vpc_subnet' do
        subnet = find_subnet("#{@name}-subnet")
        expect(@aws.tag_difference(subnet, @new_config[:tags])).to be_empty
      end

      it 'on the vpc_internet_gateway' do
        i_gateway = find_internet_gateway("#{@name}-igw")
        expect(@aws.tag_difference(i_gateway, @new_config[:tags])).to be_empty
      end

      it 'on the ec2_vpc_customer_gateway' do
        c_gateway = find_customer_gateway("#{@name}-cgw")
        expect(@aws.tag_difference(c_gateway, @new_config[:tags])).to be_empty
      end

      it 'on the ec2_vpc_vpn' do
        vpn = find_vpn("#{@name}-vpn")
        expect(@aws.tag_difference(vpn, @new_config[:tags])).to be_empty
      end
    end

    # include_context 'cleanse AWS resources for the test1'
  end
end

