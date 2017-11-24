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

  include_context 'cleanse AWS resources for the test'
  
  describe 'creating a new VPC environment with all possible properties' do
    before(:all) do
      ip_address = generate_ip
      region = @default_region
      @config = {
        # shared properties
        :name                       => @name,
        :region                     => region,
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
        :subnet_availability_zone    => "#{region}a",
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
        :vgw_availability_zone       => "#{region}a",
        :associate_public_ip_address => true,
      }
      @template = 'vpc_complete.pp.tmpl'
      result = PuppetManifest.new(@template, @config).apply
      expect(result.stderr).not_to match(/error/i)
    end

    it 'should create a public instance in the VPC' do
      instance = find_instance("#{@name}-instance")
      @aws.ec2_client.wait_until(:instance_running, instance_ids: [instance.instance_id])
      running_instance = find_instance("#{@name}-instance")
      expect(running_instance.public_ip_address).not_to be_nil
    end

    context 'using puppet resource' do
      before(:all) do
        result = PuppetManifest.new(@template, @config).apply
        expect(result.stderr).not_to match(/error/i)
      end

      context 'to describe an ec2_vpc' do
        before(:all) do
          ENV['AWS_REGION'] = @default_region
          options = {:name => "#{@name}-vpc"}
          @result = TestExecutor.puppet_resource('ec2_vpc', options, '--modulepath spec/fixtures/modules/')
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

        it 'should show the correct tags' do
          @config[:tags].each do |k,v|
            regex = /'#{k}'\s*=>\s*'#{v}'/
            expect(@result.stdout).to match(regex)
          end
        end

        it 'should show the correct dhcp_options' do
          regex = /dhcp_options\s*=>\s*'#{@name}-options'/
          expect(@result.stdout).to match(regex)
        end
      end

      context 'to describe an ec2_vpc_dhcp_options' do
        before(:all) do
          ENV['AWS_REGION'] = @default_region
          options = {:name => "#{@name}-options"}
          @result = TestExecutor.puppet_resource('ec2_vpc_dhcp_options', options, '--modulepath spec/fixtures/modules/')
        end

        it 'should show the correct tags' do
          @config[:tags].each do |k,v|
            regex = /'#{k}'\s*=>\s*'#{v}'/
            expect(@result.stdout).to match(regex)
          end
        end

        it 'should show the correct region' do
          regex = /region\s*=>\s*'#{@config[:region]}'/
          expect(@result.stdout).to match(regex)
        end

        it 'should show the correct domain name servers' do
          @config[:domain_name_servers].each do |dns|
            regex = /domain_name_servers\s*=>.*'#{dns}'/
            expect(@result.stdout).to match(regex)
          end
        end

        it 'should show the correct ntp servers' do
          @config[:ntp_servers].each do |ntp|
            regex = /ntp_servers\s*=>.*'#{ntp}'/
            expect(@result.stdout).to match(regex)
          end
        end

        it 'should show the correct netbios name servers' do
          @config[:netbios_name_servers].each do |nbns|
            regex = /netbios_name_servers\s*=>.*'#{nbns}'/
            expect(@result.stdout).to match(regex)
          end
        end

        it 'should show the correct netbios node type' do
          regex = /netbios_node_type\s*=>\s*'#{@config[:netbios_node_type]}'/
          expect(@result.stdout).to match(regex)
        end

        it 'should show the correct domain names' do
          @config[:domain_name].each do |dn|
            regex = /domain_name\s*=>.*'#{dn}'/
            expect(@result.stdout).to match(regex)
          end
        end
      end

      context 'to describe an ec2_vpc_routetable' do
        before(:all) do
          ENV['AWS_REGION'] = @default_region
          options = {:name => "#{@name}-routes"}
          @result = TestExecutor.puppet_resource('ec2_vpc_routetable', options, '--modulepath spec/fixtures/modules/')
        end

        it 'should show the correct vpc' do
          regex = /vpc\s*=>\s*'#{@name}-vpc'/
          expect(@result.stdout).to match(regex)
        end

        it 'should show the correct region' do
          regex = /region\s*=>\s*'#{@config[:region]}'/
          expect(@result.stdout).to match(regex)
        end

        it 'should show the correct routes' do
          @config[:route_settings].each do |r|
            regex = /'destination_cidr_block'\s*=>\s*'#{r[:destination_cidr_block]}',\s*'gateway'\s*=>\s*'#{r[:gateway]}'/
            expect(@result.stdout).to match(regex)
          end
        end

        it 'should show the correct tags' do
          @config[:tags].each do |k,v|
            regex = /'#{k}'\s*=>\s*'#{v}'/
            expect(@result.stdout).to match(regex)
          end
        end
      end

      context 'to describe an ec2_vpc_subnet' do
        before(:all) do
          ENV['AWS_REGION'] = @default_region
          options = {:name => "#{@name}-subnet"}
          @result = TestExecutor.puppet_resource('ec2_vpc_subnet', options, '--modulepath spec/fixtures/modules/')
        end

        it 'should show the correct vpc' do
          regex = /vpc\s*=>\s*'#{@name}-vpc'/
          expect(@result.stdout).to match(regex)
        end

        it 'should show the correct region' do
          regex = /region\s*=>\s*'#{@config[:region]}'/
          expect(@result.stdout).to match(regex)
        end

        it 'should show the correct cidr_block' do
          regex = /cidr_block\s*=>\s*'#{@config[:subnet_cidr]}'/
          expect(@result.stdout).to match(regex)
        end

        it 'should show the correct availability_zone' do
          regex = /availability_zone\s*=>\s*'#{@config[:subnet_availability_zone]}'/
          expect(@result.stdout).to match(regex)
        end

        it 'should show the correct tags' do
          @config[:tags].each do |k,v|
            regex = /'#{k}'\s*=>\s*'#{v}'/
            expect(@result.stdout).to match(regex)
          end
        end

        it 'should show the correct route_table' do
          regex = /route_table\s*=>\s*'#{@name}-routes'/
          expect(@result.stdout).to match(regex)
        end
      end

      context 'to describe an ec2_vpc_internet_gateway' do
        before(:all) do
          ENV['AWS_REGION'] = @default_region
          options = {:name => "#{@name}-igw"}
          @result = TestExecutor.puppet_resource('ec2_vpc_internet_gateway', options, '--modulepath spec/fixtures/modules/')
        end

        it 'should show the correct region' do
          regex = /region\s*=>\s*'#{@config[:region]}'/
          expect(@result.stdout).to match(regex)
        end

        it 'should show the correct tags' do
          @config[:tags].each do |k,v|
            regex = /'#{k}'\s*=>\s*'#{v}'/
            expect(@result.stdout).to match(regex)
          end
        end

        it 'should show the correct vpc' do
          regex = /vpc\s*=>.*'#{@config[:igw_vpc_setting]}'/
          expect(@result.stdout).to match(regex)
        end
      end

      context 'to describe an ec2_vpc_customer_gateway' do
        before(:all) do
          ENV['AWS_REGION'] = @default_region
          options = {:name => "#{@name}-cgw"}
          @result = TestExecutor.puppet_resource('ec2_vpc_customer_gateway', options, '--modulepath spec/fixtures/modules/')
        end

        it 'should show the correct ip_address' do
          regex = /ip_address\s*=>\s*'#{@config[:customer_ip_address]}'/
          expect(@result.stdout).to match(regex)
        end

        it 'should show the correct bgp_asn' do
          regex = /bgp_asn\s*=>\s*'#{@config[:bgp_asn]}'/
          expect(@result.stdout).to match(regex)
        end

        it 'should show the correct tags' do
          @config[:tags].each do |k,v|
            regex = /'#{k}'\s*=>\s*'#{v}'/
            expect(@result.stdout).to match(regex)
          end
        end

        it 'should show the correct region' do
          regex = /region\s*=>\s*'#{@config[:region]}'/
          expect(@result.stdout).to match(regex)
        end

        it 'should show the correct type' do
          regex = /type\s*=>\s*'#{@config[:vpn_type]}'/
          expect(@result.stdout).to match(regex)
        end
      end

      context 'to describe an ec2_vpc_vpn' do
        before(:all) do
          ENV['AWS_REGION'] = @default_region
          options = {:name => "#{@name}-vpn"}
          @result = TestExecutor.puppet_resource('ec2_vpc_vpn', options, '--modulepath spec/fixtures/modules/')
        end

        it 'should show the correct vpn_gateway' do
          regex = /vpn_gateway\s*=>\s*'#{@name}-vgw'/
          expect(@result.stdout).to match(regex)
        end

        it 'should show the correct customer_gateway' do
          regex = /customer_gateway\s*=>\s*'#{@name}-cgw'/
          expect(@result.stdout).to match(regex)
        end

        it 'should show the correct type' do
          regex = /type\s*=>\s*'#{@config[:vpn_type]}'/
          expect(@result.stdout).to match(regex)
        end

        it 'should show the correct routes' do
          @config[:vpn_routes].each do |route|
            regex = /routes\s*=>.*'#{route}'/
            expect(@result.stdout).to match(regex)
          end
        end

        it 'should show the correct static_routes' do
          regex = /static_routes\s*=>\s*#{@config[:static_routes].to_s}/
          expect(@result.stdout).to match(regex)
        end

        it 'should show the correct region' do
          regex = /region\s*=>\s*'#{@config[:region]}'/
          expect(@result.stdout).to match(regex)
        end

        it 'should show the correct tags' do
          @config[:tags].each do |k,v|
            regex = /'#{k}'\s*=>\s*'#{v}'/
            expect(@result.stdout).to match(regex)
          end
        end
      end

      context 'to describe an ec2_vpc_vpn_gateway' do
        before(:all) do
          ENV['AWS_REGION'] = @default_region
          options = {:name => "#{@name}-vgw"}
          @result = TestExecutor.puppet_resource('ec2_vpc_vpn_gateway', options, '--modulepath spec/fixtures/modules/')
        end

        it 'should show the correct tags' do
          @config[:tags].each do |k,v|
            regex = /'#{k}'\s*=>\s*'#{v}'/
            expect(@result.stdout).to match(regex)
          end
        end

        it 'should show the correct vpc' do
          regex = /vpc\s*=>\s*'#{@name}-vpc'/
          expect(@result.stdout).to match(regex)
        end

        it 'should show the correct region' do
          regex = /region\s*=>\s*'#{@config[:region]}'/
          expect(@result.stdout).to match(regex)
        end

        it 'should show the correct type' do
          regex = /type\s*=>\s*'#{@config[:vpn_type]}'/
          expect(@result.stdout).to match(regex)
        end
      end
    end
  
    include_context 'cleanse AWS resources for the test'    
  end
end
