require_relative '../../../puppet_x/puppetlabs/aws.rb'
require 'retries'

Puppet::Type.type(:ec2_vpc).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods
  remove_method :tags=

  def self.instances
    regions.collect do |region|
      response = ec2_client(region).describe_vpcs()
      vpcs = []
      response.data.vpcs.each do |vpc|
        hash = vpc_to_hash(region, vpc)
        vpcs << new(hash) if hash[:name]
      end
      vpcs
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
    {
      name: name_from_tag(vpc),
      id: vpc.vpc_id,
      cidr_block: vpc.cidr_block,
      instance_tenancy: vpc.instance_tenancy,
      ensure: :present,
      region: region,
      tags: tags_for(vpc),
    }
  end

  def exists?
    dest_region = resource[:region] if resource
    Puppet.info("Checking if VPC #{name} exists in #{dest_region || region}")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating VPC #{name}")
    ec2 = ec2_client(resource[:region])
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

    with_retries(:max_retries => 5) do
      ec2.create_tags(
        resources: [route_response.data.route_tables.first.route_table_id, vpc_id],
        tags: tags_for_resource
      )
    end
  end

  def destroy
    region = @property_hash[:region]
    Puppet.info("Deleting VPC #{name} in #{region}")
    ec2_client(region).delete_vpc(
      vpc_id: @property_hash[:id]
    )
    @property_hash[:ensure] = :absent
  end
end
