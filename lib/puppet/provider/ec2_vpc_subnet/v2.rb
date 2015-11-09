require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:ec2_vpc_subnet).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws
  confine feature: :retries

  mk_resource_methods
  remove_method :tags=

  def self.instances
    regions.collect do |region|
      begin
        response = ec2_client(region).describe_subnets()
        subnets = []
        response.data.subnets.each do |subnet|
          hash = subnet_to_hash(region, subnet)
          subnets << new(hash) if has_name?(hash)
        end
        subnets
      rescue Timeout::Error, StandardError => e
        raise PuppetX::Puppetlabs::FetchingAWSDataError.new(region, self.resource_type.name.to_s, e.message)
      end
    end.flatten
  end

  read_only(:cidr_block, :vpc, :region, :route_table, :availability_zone, :map_public_ip_on_launch)

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region
      end
    end
  end

  def self.subnet_to_hash(region, subnet)
    name = name_from_tag(subnet)
    return {} unless name
    ec2 = ec2_client(region)
    table_response = ec2.describe_route_tables(filters: [
      {name: 'association.subnet-id', values: [subnet.subnet_id]},
      {name: 'vpc-id', values: [subnet.vpc_id]},
    ])
    table_name = table_response.data.route_tables.empty? ? nil : name_from_tag(table_response.data.route_tables.first)

    {
      name: name,
      route_table: table_name,
      id: subnet.subnet_id,
      cidr_block: subnet.cidr_block,
      availability_zone: subnet.availability_zone,
      vpc: vpc_name_from_id(region, subnet.vpc_id),
      ensure: :present,
      region: region,
      map_public_ip_on_launch: subnet.map_public_ip_on_launch,
      tags: tags_for(subnet),
    }
  end

  def exists?
    Puppet.info("Checking if subnet #{name} exists in #{target_region}")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating subnet #{name} in #{target_region}")
    ec2 = ec2_client(target_region)
    vpc_response = ec2.describe_vpcs(filters: [
      {name: "tag:Name", values: [resource[:vpc]]},
    ])
    fail("Multiple VPCs with name #{resource[:vpc]}") if vpc_response.data.vpcs.count > 1
    fail("No VPCs with name #{resource[:vpc]}") if vpc_response.data.vpcs.empty?
    response = ec2.create_subnet(
      cidr_block: resource[:cidr_block],
      availability_zone: resource[:availability_zone],
      vpc_id: vpc_response.data.vpcs.first.vpc_id,
    )
    subnet_id = response.data.subnet.subnet_id
    with_retries(:max_tries => 5) do
      ec2.create_tags(
        resources: [subnet_id],
        tags: tags_for_resource,
      )
    end
    if resource[:map_public_ip_on_launch] == :true
      ec2.modify_subnet_attribute(
        subnet_id: subnet_id,
        map_public_ip_on_launch: {value: true}
      )
    end
    route_table_name = resource[:route_table]
    if route_table_name
      table_response = ec2.describe_route_tables(filters: [
        {name: 'tag:Name', values: [route_table_name]},
      ])
      fail("Multiple Route tables with name #{route_table_name}") if table_response.data.route_tables.count > 1
      fail("No Route tables with name #{route_table_name}") if table_response.data.route_tables.empty?
      ec2.associate_route_table(
        subnet_id: subnet_id,
        route_table_id: table_response.data.route_tables.first.route_table_id,
      )
    end
  end

  def destroy
    Puppet.info("Deleting subnet #{name} in #{target_region}")
    ec2_client(target_region).delete_subnet(
      subnet_id: @property_hash[:id]
    )
    @property_hash[:ensure] = :absent
  end
end
