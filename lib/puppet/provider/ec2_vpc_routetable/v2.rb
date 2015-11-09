require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:ec2_vpc_routetable).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws
  confine feature: :retries

  mk_resource_methods
  remove_method :tags=

  def self.instances
    regions.collect do |region|
      begin
        response = ec2_client(region).describe_route_tables()
        tables = []
        response.data.route_tables.each do |table|
          hash = route_table_to_hash(region, table)
          tables << new(hash) if has_name?(hash)
        end
        tables
      rescue Timeout::Error, StandardError => e
        raise PuppetX::Puppetlabs::FetchingAWSDataError.new(region, self.resource_type.name.to_s, e.message)
      end
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
    gateway_name = route.state == 'active' ? gateway_name_from_id(region, route.gateway_id) : nil
    hash = {
      'destination_cidr_block' => route.destination_cidr_block,
      'gateway' => gateway_name,
    }
    gateway_name.nil? ? nil : hash
  end

  def self.route_table_to_hash(region, table)
    name = name_from_tag(table)
    return {} unless name
    routes = table.routes.collect do |route|
      route_to_hash(region, route)
    end.compact
    {
      name: name,
      id: table.route_table_id,
      vpc: vpc_name_from_id(region, table.vpc_id),
      ensure: :present,
      routes: routes,
      region: region,
      tags: tags_for(table),
    }
  end

  def exists?
    Puppet.info("Checking if Route table #{name} exists in #{target_region}")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating Route table #{name} in #{target_region}")
    ec2 = ec2_client(target_region)

    routes = resource[:routes]
    routes = [routes] unless routes.is_a?(Array)

    vpc_response = ec2.describe_vpcs(filters: [
      {name: "tag:Name", values: [resource[:vpc]]},
    ])
    fail "Multiple VPCs with name #{resource[:vpc]}" if vpc_response.data.vpcs.count > 1
    fail "No VPCs with name #{resource[:vpc]}" if vpc_response.data.vpcs.empty?

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
    routes.each do |route|
      internet_gateway_response = ec2.describe_internet_gateways(filters: [
        {name: 'tag:Name', values: [route['gateway']]},
      ])
      found_internet_gateway = !internet_gateway_response.data.internet_gateways.empty?

      unless found_internet_gateway
        vpn_gateway_response = ec2.describe_vpn_gateways(filters: [
          {name: 'tag:Name', values: [route['gateway']]},
        ])
        found_vpn_gateway = !vpn_gateway_response.data.vpn_gateways.empty?
      end

      gateway_id = if found_internet_gateway
                     internet_gateway_response.data.internet_gateways.first.internet_gateway_id
                   elsif found_vpn_gateway
                     vpn_gateway_response.data.vpn_gateways.first.vpn_gateway_id
                   else
                     nil
                   end

      ec2.create_route(
        route_table_id: id,
        destination_cidr_block: route['destination_cidr_block'],
        gateway_id: gateway_id,
      ) if gateway_id
    end
    @property_hash[:ensure] = :present
  end

  def destroy
    Puppet.info("Deleting Route table #{name} in #{target_region}")
    ec2_client(target_region).delete_route_table(route_table_id: @property_hash[:id])
    @property_hash[:ensure] = :absent
  end
end
