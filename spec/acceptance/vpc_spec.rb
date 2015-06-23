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
        :lb_name => "#{PuppetManifest.env_dns_id}#{SecureRandom.uuid}".gsub('-', '')[0...31], # loadbalancer has name length limit
        :region => region,
        :ensure => 'present',
        :netbios_node_type => 2,
        :vpc_cidr => '10.0.0.0/16',
        :vpc_instance_tenancy => 'default',
        :subnet_cidr => '10.0.0.0/24',
        :subnet_availability_zone => "#{region}a",
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
          :department => 'engineering',
          :project => 'cloud',
          :created_by => 'aws-acceptance',
        },
      }

      @template = 'vpc.pp.tmpl'
      @result = PuppetManifest.new(@template, @config).apply

      @vpc = find_vpc("#{@name}-vpc")
      @option = find_dhcp_option("#{@name}-options")
      @subnet = find_subnet("#{@name}-subnet")
      @vgw = find_vpn_gateway("#{@name}-vgw")
      @cgw = find_customer_gateway("#{@name}-cgw")
      @sg = find_security_group("#{@name}-sg")
    end

    after(:all) do
      new_config = @config.update({:ensure => 'absent'})
      template = 'vpc_delete.pp.tmpl'
      PuppetManifest.new(template, new_config).apply
    end


    it 'should run successfully first time with changes' do
      expect(@result.exit_code).to eq(2)
    end

    it 'should run idempotently' do
      result = PuppetManifest.new(@template, @config).apply
      expect(result.exit_code).to eq(0)
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

    it 'should create a VPC associated security group' do
      expect(@sg).not_to be_nil
      expect(@sg.vpc_id).to eq(@vpc.vpc_id)
      expect(@aws.tag_difference(@sg, @config[:tags])).to be_empty
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
      expect(@subnet.map_public_ip_on_launch).to eq(@config[:map_public_ip_on_launch])
      expect(@subnet.default_for_az).to be_falsy
      expect(@aws.tag_difference(@subnet, @config[:tags])).to be_empty
    end

    it 'should create a load balancer in the VPC' do
      lb = find_load_balancer(@config[:lb_name])
      expect(lb.vpc_id).to eq(@vpc.vpc_id)
      expect(lb.subnets).to eq([@subnet.subnet_id])
      expect(lb.availability_zones).to eq([@config[:subnet_availability_zone]])
      expect(lb.instances.size).to eq(1)
      expect(lb.security_groups).not_to be_empty
      expect(lb.scheme).to eq(@config[:lb_scheme])
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

    it 'should create a private instance in the VPC' do
      instance = find_instance("#{@name}-instance")
      expect(instance.subnet_id).to eq(@subnet.subnet_id)
      expect(instance.vpc_id).to eq(@vpc.vpc_id)
      expect(instance.public_ip_address).to be_nil
    end

    context 'change tags' do
      before(:all) do
        expect(@aws.tag_difference(@vpc, @config[:tags])).to be_empty
        expect(@aws.tag_difference(@option, @config[:tags])).to be_empty
        expect(@aws.tag_difference(@subnet, @config[:tags])).to be_empty
        expect(@aws.tag_difference(@vgw, @config[:tags])).to be_empty
        expect(@aws.tag_difference(@cgw, @config[:tags])).to be_empty
        expect(@aws.tag_difference(@vpc, @config[:tags])).to be_empty
        expect(@aws.tag_difference(@vpc, @config[:tags])).to be_empty
        expect(@aws.tag_difference(@vpc, @config[:tags])).to be_empty
        tags = {
          :department => 'engineering',
          :created_by => 'aws-acceptance',
          :foo => 'bar',
        }
        @new_config = @config.dup.update(tags)
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

  end

  describe 'creating a new VPC environment with all possible properties' do

    before(:all) do
      @name = "#{PuppetManifest.env_id}-#{SecureRandom.uuid}"
      ip_address = generate_ip
      region = 'sa-east-1'
      @config = {
        # shared properties
        :name                       => @name,
        :region                     => region,
        :ensure                     => 'present',
        :tags                       => {
          :department     => 'engineering',
          :project        => 'cloud',
          :created_by     => 'aws-acceptance',
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

    after(:all) do
      # remove all resources
      template = 'vpc_complete_delete.pp.tmpl'
      config = {:name => @config[:name], :region => @config[:region], :ensure => 'absent'}
      result = PuppetManifest.new(template, config).apply
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
          @result = TestExecutor.puppet_resource('ec2_vpc_dhcp_options', options, '--modulepath ../')
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
          @result = TestExecutor.puppet_resource('ec2_vpc_routetable', options, '--modulepath ../')
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
          @result = TestExecutor.puppet_resource('ec2_vpc_subnet', options, '--modulepath ../')
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
          @result = TestExecutor.puppet_resource('ec2_vpc_internet_gateway', options, '--modulepath ../')
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
          @result = TestExecutor.puppet_resource('ec2_vpc_customer_gateway', options, '--modulepath ../')
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
          @result = TestExecutor.puppet_resource('ec2_vpc_vpn', options, '--modulepath ../')
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
          regex = /static_routes\s*=>\s*'#{@config[:static_routes].to_s}'/
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
          @result = TestExecutor.puppet_resource('ec2_vpc_vpn_gateway', options, '--modulepath ../')
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

  end

  describe 'Negative cases for VPC' do

    before(:all) do
      @template = 'vpc_complete.pp.tmpl'
      name = "#{PuppetManifest.env_id}-#{SecureRandom.uuid}"
      region = @default_region
      ip_address = generate_ip
      @negative_config = {
        # shared properties
        :name                       => name,
        :region                     => region,
        :ensure                     => 'present',
        :tags                       => {
          :department     => 'engineering',
          :project        => 'cloud',
          :created_by     => 'aws-acceptance',
        },
        :vpn_type                   => 'ipsec.1',
        # ec2_vpc properties
        :vpc_cidr                   => '10.0.0.0/16',
        :dhcp_options_setting       => "#{name}-options",
        :vpc_instance_tenancy       => 'default',
        # ec2_vpc_dhcp_options properties
        :netbios_node_type          => 2,
        :netbios_name_servers       => ['172.16.48.16', '172.16.48.32','172.16.48.48'],
        :ntp_servers                => ['172.16.32.16', '172.16.32.32','172.16.32.48'],
        :domain_name_servers        => ['172.16.16.16', '172.16.16.32','172.16.16.48'],
        :domain_name                => ['example.com', 'example2.com', 'example3.com'],
        # ec2_vpc_routetable properties
        :routetable_vpc_setting     => "#{name}-vpc",
        :route_settings             => [
          {
            # igw
            :destination_cidr_block => '10.50.50.50/31',
            :gateway                => "#{name}-igw",
          },
          {
            # vgw
            :destination_cidr_block => '10.20.20.20/30',
            :gateway                => "#{name}-vgw",
          },
          {
            :destination_cidr_block => '10.0.0.0/16',
            :gateway                => 'local',
          },
        ],
        # ec2_vpc_subnet properties
        :subnet_vpc_setting          => "#{name}-vpc",
        :subnet_cidr                 => '10.0.0.0/24',
        :subnet_availability_zone    => "#{region}a",
        :subnet_route_table_setting  => "#{name}-routes",
        # ec2_vpc_internet_gateway properties
        :igw_vpc_setting             => "#{name}-vpc",
        # ec2_vpc_customer_gateway properties
        :customer_ip_address         => ip_address,
        :bgp_asn                     => '65000',
        # ec2_vpc_vpn properties
        :vpn_vgw_setting             => "#{name}-vgw",
        :vpn_cgw_setting             => "#{name}-cgw",
        :vpn_routes                  => ['0.0.0.0/0', '0.0.0.50/31'],
        :static_routes               => true,
        # ec2_vpc_vpn_gateway properites
        :vgw_vpc_setting             => "#{name}-vpc",
        :vgw_availability_zone       => "#{region}a",
        :associate_public_ip_address => false,
      }
    end

    after(:each) do
      template = 'vpc_complete_delete.pp.tmpl'
      config = {:name => @negative_config[:name], :region => @negative_config[:region], :ensure => 'absent'}
      result = PuppetManifest.new(template, config).apply
      expect(result.stderr).not_to match(/error/i)
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
      result = PuppetManifest.new(@template, @negative_config).apply
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
      regex = /Error: routes property is read-only once ec2_vpc_routetable created/
      expect(result2.stderr).to match(regex)
    end

  end

  describe 'deleteing all types with puppet resource' do

    before(:all) do
      name = "#{PuppetManifest.env_id}-#{SecureRandom.uuid}"
      region = @default_region
      ip_address = generate_ip
      @delete_me = {
        # shared properties
        :name                       => name,
        :region                     => region,
        :ensure                     => 'present',
        :tags                       => {
          :department     => 'engineering',
          :project        => 'cloud',
          :created_by     => 'aws-acceptance',
        },
        :vpn_type                   => 'ipsec.1',
        # ec2_vpc properties
        :vpc_cidr                   => '10.0.0.0/16',
        :dhcp_options_setting       => "#{name}-options",
        :vpc_instance_tenancy       => 'default',
        # ec2_vpc_dhcp_options properties
        :netbios_node_type          => 2,
        :netbios_name_servers       => ['172.16.48.16', '172.16.48.32','172.16.48.48'],
        :ntp_servers                => ['172.16.32.16', '172.16.32.32','172.16.32.48'],
        :domain_name_servers        => ['172.16.16.16', '172.16.16.32','172.16.16.48'],
        :domain_name                => ['example.com', 'example2.com', 'example3.com'],
        # ec2_vpc_routetable properties
        :routetable_vpc_setting     => "#{name}-vpc",
        :route_settings             => [
          {
            # igw
            :destination_cidr_block => '10.50.50.50/31',
            :gateway                => "#{name}-igw",
          },
          {
            # vgw
            :destination_cidr_block => '10.20.20.20/30',
            :gateway                => "#{name}-vgw",
          },
          {
            :destination_cidr_block => '10.0.0.0/16',
            :gateway                => 'local',
          },
        ],
        # ec2_vpc_subnet properties
        :subnet_vpc_setting         => "#{name}-vpc",
        :subnet_cidr                => '10.0.0.0/24',
        :subnet_availability_zone   => "#{region}a",
        :subnet_route_table_setting => "#{name}-routes",
        # ec2_vpc_internet_gateway properties
        :igw_vpc_setting            => "#{name}-vpc",
        # ec2_vpc_customer_gateway properties
        :customer_ip_address        => ip_address,
        :bgp_asn                    => '65000',
        # ec2_vpc_vpn properties
        :vpn_vgw_setting            => "#{name}-vgw",
        :vpn_cgw_setting            => "#{name}-cgw",
        :vpn_routes                 => ['0.0.0.0/0', '0.0.0.50/31'],
        :static_routes              => true,
        # ec2_vpc_vpn_gateway properites
        :vgw_vpc_setting            => "#{name}-vpc",
        :vgw_availability_zone      => "#{region}a",
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
      result = TestExecutor.puppet_resource('ec2_instance', options, '--modulepath ../')
      expect(result.stderr).not_to match(/Error/), error_message
      expect(@aws.send('get_instances', instance_name).first.state.name).to eq('terminated')
      # igw
      igw_name = "#{@delete_me[:name]}-igw"
      options = {:name => igw_name, :region => @default_region, :ensure => 'absent'}
      result = TestExecutor.puppet_resource('ec2_vpc_internet_gateway', options, '--modulepath ../')
      expect(result.stderr).not_to match(/Error/), error_message
      expect(@aws.send('get_vpn_gateways', igw_name)).to be_empty
      # vpn
      vpn_name = "#{@delete_me[:name]}-vpn"
      options = {:name => vpn_name, :region => @default_region, :ensure => 'absent'}
      result = TestExecutor.puppet_resource('ec2_vpc_vpn', options, '--modulepath ../')
      expect(result.stderr).not_to match(/Error/), error_message
      expect(@aws.send('get_vpn', vpn_name)).to be_empty
      # cgw
      cgw_name = "#{@delete_me[:name]}-cgw"
      options = {:name => cgw_name, :region => @default_region, :ensure => 'absent'}
      result = TestExecutor.puppet_resource('ec2_vpc_customer_gateway', options, '--modulepath ../')
      expect(result.stderr).not_to match(/Error/), error_message
      expect(@aws.send('get_customer_gateways', cgw_name)).to be_empty
      # vpn gateway
      vgw_name = "#{@delete_me[:name]}-vgw"
      options = {:name => vgw_name, :region => @default_region, :ensure => 'absent'}
      result = TestExecutor.puppet_resource('ec2_vpc_vpn_gateway', options, '--modulepath ../')
      expect(result.stderr).not_to match(/Error/), error_message
      expect(@aws.send('get_vpn_gateways', vgw_name)).to be_empty
      # subnet
      subnet_name = "#{@delete_me[:name]}-subnet"
      options = {:name => subnet_name, :region => @default_region, :ensure => 'absent'}
      result = TestExecutor.puppet_resource('ec2_vpc_subnet', options, '--modulepath ../')
      expect(result.stderr).not_to match(/Error/), error_message
      expect(@aws.send('get_subnets', subnet_name)).to be_empty
      # routes
      routes_name = "#{@delete_me[:name]}-routes"
      options = {:name => routes_name, :region => @default_region, :ensure => 'absent'}
      result = TestExecutor.puppet_resource('ec2_vpc_routetable', options, '--modulepath ../')
      expect(result.stderr).not_to match(/Error/), error_message
      expect(@aws.send('get_route_tables', routes_name)).to be_empty
      # vpc
      vpc_name = "#{@delete_me[:name]}-vpc"
      options = {:name => vpc_name, :region => @default_region, :ensure => 'absent'}
      result = TestExecutor.puppet_resource('ec2_vpc', options, '--modulepath ../')
      expect(result.stderr).not_to match(/Error/), error_message
      expect(@aws.send('get_vpcs', vpc_name)).to be_empty
      # dhcp options
      options_name = "#{@delete_me[:name]}-options"
      options = {:name => options_name, :region => @default_region, :ensure => 'absent'}
      result = TestExecutor.puppet_resource('ec2_vpc_dhcp_options', options, '--modulepath ../')
      expect(result.stderr).not_to match(/Error/), error_message
      expect(@aws.send('get_dhcp_options', options_name)).to be_empty
    end

  end

end
