require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:ec2_vpc_route_table).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    regions.collect do |region|
      response = ec2_client(region: region).describe_route_tables()
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
    ec2 = ec2_client(region: region)
    if route.gateway_id == 'local'
      gateway = 'local'
    else
      igw_response = ec2.describe_internet_gateways(internet_gateway_ids: [route.gateway_id])
      igw_name_tag = igw_response.data.internet_gateways.first.tags.detect { |tag| tag.key == 'Name' }
      gateway = igw_name_tag ? igw_name_tag.value : nil
    end
    {
      'destination_cidr_block' => route.destination_cidr_block,
      'gateway' => gateway,
    }
  end

  def self.route_table_to_hash(region, table)
    ec2 = ec2_client(region: region)
    vpc_response = ec2.describe_vpcs(vpc_ids: [table.vpc_id])
    vpc_name_tag = vpc_response.data.vpcs.first.tags.detect { |tag| tag.key == 'Name' }
    name_tag = table.tags.detect { |tag| tag.key == 'Name' }

    routes = []
    table.routes.each do |route|
      routes << route_to_hash(region, route)
    end

    {
      name: name_tag ? name_tag.value : nil,
      id: table.route_table_id,
      vpc: vpc_name_tag ? vpc_name_tag.value : nil,
      ensure: :present,
      routes: routes,
      region: region,
    }
  end

  def exists?
    Puppet.info("Checking if route table #{name} exists")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating route table #{name}")
    ec2 = ec2_client(region: resource[:region])
    vpc_response = ec2.describe_vpcs(filters: [
      {name: "tag:Name", values: [resource[:vpc]]},
    ])
    response = ec2.create_route_table(
      vpc_id: vpc_response.data.vpcs.first.vpc_id,
    )
    id = response.data.route_table.route_table_id
    ec2.create_tags(
      resources: [id],
      tags: [{key: 'Name', value: name}]
    )
    resource[:routes].each do |route|
      gateway_response = ec2.describe_internet_gateways(filters: [
        {name: "tag:Name", values: [route['gateway']]},
      ])
      ec2.create_route(
        route_table_id: id,
        destination_cidr_block: route['destination_cidr_block'],
        gateway_id: gateway_response.data.internet_gateways.first.internet_gateway_id,
      )
    end
  end

  def destroy
    Puppet.info("Deleting route table #{name}")
    ec2 = ec2_client(region: resource[:region])
    response = ec2.describe_route_tables(filters: [
      {name: 'tag:Name', values: [name]},
    ])
    fail("Multiple route tables with name #{name}. Not deleting.") if response.data.route_tables.count > 1
    ec2.delete_route_table(route_table_id: response.data.route_tables.first.route_table_id)
  end
end

