require_relative '../../../puppet_x/puppetlabs/aws.rb'
require 'retries'

Puppet::Type.type(:ec2_vpc_vpn).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods
  remove_method :tags=

  def self.instances()
    regions.collect do |region|
      connections = []
      ec2_client(region).describe_vpn_connections.each do |response|
        response.data.vpn_connections.each do |connection|
          hash = connection_to_hash(region, connection)
          if hash[:name]
            connections << new(hash) unless (connection.state == "deleting" or connection.state == "deleted")
          end
        end
      end
      connections
    end.flatten
  end

  read_only(:vpc_gateway, :customer_gateway, :type, :routing, :static_routes, :region)

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]  # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov
      end
    end
  end

  def self.connection_to_hash(region, connection)
    ec2 = ec2_client(region)

    customer_response = ec2.describe_customer_gateways(
      customer_gateway_ids: [connection.customer_gateway_id]
    )

    customer_gateways = customer_response.data.customer_gateways
    customer_gateway_name = unless customer_gateways.empty?
      customer_name_tag = customer_gateways.first.tags.detect { |tag| tag.key == 'Name' }
      customer_name_tag ? customer_name_tag.value : nil
    else
      nil
    end

    vpn_response = ec2.describe_vpn_gateways(
      vpn_gateway_ids: [connection.vpn_gateway_id]
    )

    vpn_gateways = vpn_response.data.vpn_gateways
    vpn_gateway_name = unless vpn_gateways.empty?
      vpn_name_tag = vpn_gateways.first.tags.detect { |tag| tag.key == 'Name' }
      vpn_name_tag ? vpn_name_tag.value : nil
    else
      nil
    end

    routes = connection.routes.collect { |route| route.destination_cidr_block }

    {
      :name             => name_from_tag(connection),
      :id               => connection.vpn_connection_id,
      :customer_gateway => customer_gateway_name,
      :ensure           => :present,
      :region           => region,
      :type             => connection.type,
      :vpn_gateway      => vpn_gateway_name,
      :routes           => routes,
      :static_routes    => connection.options.static_routes_only,
      :tags             => tags_for(connection),
    }
  end

  def exists?
    dest_region = resource[:region] if resource
    Puppet.info("Checking if VPN #{name} exists in region #{dest_region || region}")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating VPN gateway #{name} in region #{resource[:region]}")
    ec2 = ec2_client(resource[:region])

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
    region = @property_hash[:region]
    Puppet.info("Destroying VPN #{name} in region #{region}")
    ec2 = ec2_client(region)
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

