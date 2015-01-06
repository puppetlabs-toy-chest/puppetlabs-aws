require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:ec2_vpc).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

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
    name_tag = vpc.tags.detect { |tag| tag.key == 'Name' }
    {
      name: name_tag ? name_tag.value : nil,
      id: vpc.vpc_id,
      cidr_block: vpc.cidr_block,
      instance_tenancy: vpc.instance_tenancy,
      ensure: :present,
      region: region,
    }
  end

  def exists?
    Puppet.info("Checking if VPC #{name} exists")
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
    ec2.create_tags(
      resources: [route_response.data.route_tables.first.route_table_id, vpc_id],
      tags: [{key: 'Name', value: name}]
    )
  end

  def destroy
    Puppet.info("Deleting VPC #{name}}")
    ec2_client(resource[:region]).delete_vpc(
      vpc_id: @remote_hash[:vpc_id]
    )
  end
end

