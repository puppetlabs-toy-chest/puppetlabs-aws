require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:ec2_vpc_vpn).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws
  confine feature: :retries

  mk_resource_methods
  remove_method :tags=

  def self.instances()
    regions.collect do |region|
      begin
        connections = []
        ec2_client(region).describe_vpn_connections(filters: [
          {:name => 'state', :values => ['pending', 'available']}
        ]).each do |response|
          response.data.vpn_connections.each do |connection|
            hash = connection_to_hash(region, connection)
            connections << new(hash) if has_name?(hash)
          end
        end
        connections
      rescue Timeout::Error, StandardError => e
        raise PuppetX::Puppetlabs::FetchingAWSDataError.new(region, self.resource_type.name.to_s, e.message)
      end
    end.flatten
  end

  read_only(:vpn_gateway, :customer_gateway, :type, :routing, :static_routes, :region)

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]  # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov
      end
    end
  end

  def self.connection_to_hash(region, connection)
    name = name_from_tag(connection)
    return {} unless name

    customer_gateway_name = customer_gateway_name_from_id(region, connection.customer_gateway_id)
    vpn_gateway_name = vpn_gateway_name_from_id(region, connection.vpn_gateway_id)

    routes = connection.routes.collect { |route| route.destination_cidr_block }
    static_routes = connection.options.nil? ? nil : connection.options.static_routes_only

    {
      :name             => name,
      :id               => connection.vpn_connection_id,
      :customer_gateway => customer_gateway_name,
      :ensure           => :present,
      :region           => region,
      :type             => connection.type,
      :vpn_gateway      => vpn_gateway_name,
      :routes           => routes,
      :static_routes    => static_routes,
      :tags             => tags_for(connection),
    }
  end

  def exists?
    Puppet.debug("Checking if VPN #{name} exists in region #{target_region}")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating VPN gateway #{name} in region #{target_region}")
    ec2 = ec2_client(target_region)

    vpn_response = ec2.describe_vpn_gateways(filters: [
      {name: "tag:Name", values: [resource[:vpn_gateway]]},
    ])
    fail("Multiple VPN gateways with name #{resource[:vpn_gateway]}") if vpn_response.data.vpn_gateways.count > 1
    fail("No VPN gateway with name #{resource[:vpn_gateway]}") if vpn_response.data.vpn_gateways.empty?

    customer_response = ec2.describe_customer_gateways(filters: [
      {name: "tag:Name", values: [resource[:customer_gateway]]},
    ])
    fail("Multiple Customer gateways with name #{resource[:customer_gateway]}") if customer_response.data.customer_gateways.count > 1
    fail("No Customer gateway with name #{resource[:customer_gateway]}") if customer_response.data.customer_gateways.empty?

    response = ec2.create_vpn_connection(
      type: resource[:type],
      customer_gateway_id: customer_response.data.customer_gateways.first.customer_gateway_id,
      vpn_gateway_id: vpn_response.data.vpn_gateways.first.vpn_gateway_id,
      options: {
        static_routes_only: resource[:static_routes].to_s,
      }
    )

    vpn_connection_id = response.data.vpn_connection.vpn_connection_id

    with_retries(:max_tries => 5) do
      ec2.create_tags(
        resources: [vpn_connection_id],
        tags: tags_for_resource,
      )
    end

    ec2.wait_until(:vpn_connection_available, vpn_connection_ids: [vpn_connection_id]) unless resource[:routes].empty?

    resource[:routes].each do |cidr|
      ec2.create_vpn_connection_route(
        vpn_connection_id: vpn_connection_id,
        destination_cidr_block: cidr,
      )
    end

    @property_hash[:ensure] = :present
  end

  def destroy
    Puppet.info("Destroying VPN #{name} in region #{target_region}")
    ec2 = ec2_client(target_region)
    ec2.delete_vpn_connection(
      vpn_connection_id: @property_hash[:id]
    )
    # We wait for deletion here as other resources like
    # customer gateways can't be deleted until the vpn connection
    # has terminated
    ec2.wait_until(:vpn_connection_deleted, vpn_connection_ids: [@property_hash[:id]])
    @property_hash[:ensure] = :absent
  end
end
