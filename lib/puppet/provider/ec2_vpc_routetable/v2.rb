require_relative '../../../puppet_x/puppetlabs/aws.rb'
require 'retries'

Puppet::Type.type(:ec2_vpc_routetable).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods
  remove_method :tags=

  def self.instances
    regions.collect do |region|
      response = ec2_client(region).describe_route_tables()
      tables = []
      response.data.route_tables.each do |table|
        hash = route_table_to_hash(region, table)
        tables << new(hash) if hash[:name]
      end
      tables
    end.flatten
  end

  read_only(:region, :vpc, :routes)

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region
      end
    end
  end

  def self.route_to_hash(region, route)
    ec2 = ec2_client(region)
    gateway = if route.gateway_id == 'local'
      'local'
    else
      begin
        igw_response = ec2.describe_internet_gateways(internet_gateway_ids: [route.gateway_id])
        name_from_tag(igw_response.data.internet_gateways.first)
      rescue Aws::EC2::Errors::InvalidInternetGatewayIDNotFound
        nil
      end
    end
    {
      'destination_cidr_block' => route.destination_cidr_block,
      'gateway' => gateway,
    }
  end

  def self.route_table_to_hash(region, table)
    ec2 = ec2_client(region)
    vpc_response = ec2.describe_vpcs(vpc_ids: [table.vpc_id])
    vpc_name_tag = vpc_response.data.vpcs.first.tags.detect { |tag| tag.key == 'Name' }

    routes = table.routes.collect do |route|
      route_to_hash(region, route)
    end

    {
      name: name_from_tag(table),
      id: table.route_table_id,
      vpc: vpc_name_tag ? vpc_name_tag.value : nil,
      ensure: :present,
      routes: routes,
      region: region,
      tags: tags_for(table),
    }
  end

  def exists?
    dest_region = resource[:region] if resource
    Puppet.info("Checking if Route table #{name} exists in #{dest_region || region}")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating Route table #{name}")
    ec2 = ec2_client(resource[:region])

    vpc_response = ec2.describe_vpcs(filters: [
      {name: "tag:Name", values: [resource[:vpc]]},
    ])
    fail("Multiple VPCs with name #{resource[:vpc]}") if vpc_response.data.vpcs.count > 1
    fail("No VPCs with name #{resource[:vpc]}") if vpc_response.data.vpcs.empty?

    response = ec2.create_route_table(
      vpc_id: vpc_response.data.vpcs.first.vpc_id,
    )
    id = response.data.route_table.route_table_id
    with_retries(:max_tries => 5) do
      ec2.create_tags(
        resources: [id],
        tags: tags_for_resource,
      )
    end
    resource[:routes].each do |route|
      gateway_response = ec2.describe_internet_gateways(filters: [
        {name: "tag:Name", values: [route['gateway']]},
      ])
      ec2.create_route(
        route_table_id: id,
        destination_cidr_block: route['destination_cidr_block'],
        gateway_id: gateway_response.data.internet_gateways.first.internet_gateway_id,
      ) unless gateway_response.data.internet_gateways.empty?
    end if resource[:routes]
    @property_hash[:ensure] = :present
  end

  def destroy
    region = @property_hash[:region]
    Puppet.info("Deleting Route table #{name} in #{region}")
    ec2_client(region).delete_route_table(route_table_id: @property_hash[:id])
    @property_hash[:ensure] = :absent
  end
end

