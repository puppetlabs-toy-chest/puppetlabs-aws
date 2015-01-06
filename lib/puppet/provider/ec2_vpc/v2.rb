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

  read_only(:cidr_block)

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
      cidr_block: vpc.cidr_block,
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
      cidr_block: resource[:cidr_block]
    )
    route_response = ec2.describe_route_tables(filters: [
      {name: 'vpc-id', values: [response.data.vpc.vpc_id]},
      {name: 'association.main', values: ['true']},
    ])
    ec2.create_tags(
      resources: [route_response.data.route_tables.first.route_table_id, response.data.vpc.vpc_id],
      tags: [{key: 'Name', value: name}]
    )
  end

  def destroy
    Puppet.info("Deleting VPC #{name}}")
    ec2 = ec2_client(resource[:region])
    response = ec2.describe_vpcs(filters: [
      {name: 'tag:Name', values: [name]},
    ])
    fail("Multiple VPCs with name #{name}. Not deleting.") if response.data.vpcs.count > 1
    response.data.vpcs.each do |vpc|
      ec2.delete_vpc(
        vpc_id: vpc.vpc_id
      )
    end
  end
end

