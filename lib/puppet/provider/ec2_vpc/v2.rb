require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:ec2_vpc).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws
  confine feature: :retries

  mk_resource_methods
  remove_method :tags=

  def self.instances
    regions.collect do |region|
      begin
        response = ec2_client(region).describe_vpcs()
        vpcs = []
        response.data.vpcs.each do |vpc|
          hash = vpc_to_hash(region, vpc)
          vpcs << new(hash) if has_name?(hash)
        end
        vpcs
      rescue Timeout::Error, StandardError => e
        raise PuppetX::Puppetlabs::FetchingAWSDataError.new(region, self.resource_type.name.to_s, e.message)
      end
    end.flatten
  end

  read_only(:cidr_block, :dhcp_options, :instance_tenancy, :region)

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region
      end
    end
  end

  def self.vpc_to_hash(region, vpc)
    name = name_from_tag(vpc)
    return {} unless name
    ec2 = ec2_client(region)
    {
      name: name,
      id: vpc.vpc_id,
      cidr_block: vpc.cidr_block,
      instance_tenancy: vpc.instance_tenancy,
      ensure: :present,
      region: region,
      enable_dns_support: ec2.describe_vpc_attribute({vpc_id: vpc.vpc_id, attribute: "enableDnsSupport"}).enable_dns_support.value,
      enable_dns_hostnames: ec2.describe_vpc_attribute({vpc_id: vpc.vpc_id, attribute: "enableDnsHostnames"}).enable_dns_hostnames.value,
      tags: tags_for(vpc),
      dhcp_options: options_name_from_id(region, vpc.dhcp_options_id),
    }
  end

  def exists?
    Puppet.debug("Checking if VPC #{name} exists in #{target_region}")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating VPC #{name} in #{target_region}")
    ec2 = ec2_client(target_region)
    response = ec2.create_vpc(
      cidr_block: resource[:cidr_block],
      instance_tenancy: resource[:instance_tenancy]
    )
    vpc_id = response.data.vpc.vpc_id

    options_name = resource[:dhcp_options]
    if options_name
      options_response = ec2.describe_dhcp_options(filters: [
        {name: 'tag:Name', values: [options_name]},
      ])

      fail("No DHCP options with name #{options_name}") if options_response.data.dhcp_options.count == 0
      fail("Multiple DHCP options with name #{options_name}") if options_response.data.dhcp_options.count > 1

      ec2.associate_dhcp_options(
        dhcp_options_id: options_response.data.dhcp_options.first.dhcp_options_id,
        vpc_id: vpc_id,
      )
    end

    # When creating a VPC a Route Table is automatically created
    # We want to name to the same as the VPC so we can find it later
    route_response = ec2.describe_route_tables(filters: [
      {name: 'vpc-id', values: [response.data.vpc.vpc_id]},
      {name: 'association.main', values: ['true']},
    ])

    resources = route_response.data.route_tables.collect(&:route_table_id)
    resources << vpc_id

    ec2.modify_vpc_attribute({vpc_id: vpc_id,
                              enable_dns_support: {value: resource[:enable_dns_support] == :true}})
    ec2.modify_vpc_attribute({vpc_id: vpc_id,
                              enable_dns_hostnames: {value: resource[:enable_dns_hostnames] == :true}})

    with_retries(:max_tries => 5) do
      ec2.create_tags(
        resources: resources,
        tags: tags_for_resource
      )
    end
  end

  def destroy
    Puppet.info("Deleting VPC #{name} in #{target_region}")
    ec2_client(target_region).delete_vpc(
      vpc_id: @property_hash[:id]
    )
    @property_hash[:ensure] = :absent
  end
end
