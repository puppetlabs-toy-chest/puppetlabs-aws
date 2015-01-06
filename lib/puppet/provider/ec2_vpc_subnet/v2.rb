require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:ec2_vpc_subnet).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    regions.collect do |region|
      response = ec2_client(region).describe_subnets()
      subnets = []
      response.data.subnets.each do |subnet|
        hash = subnet_to_hash(region, subnet)
        subnets << new(hash) if hash[:name]
      end
      subnets
    end.flatten
  end

  read_only(:cidr_block, :vpc)

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region
      end
    end
  end

  def self.subnet_to_hash(region, subnet)
    vpc_response = ec2_client(region).describe_vpcs(vpc_ids: [subnet.vpc_id])
    vpc_name_tag = vpc_response.data.vpcs.first.tags.detect { |tag| tag.key == 'Name' }
    name_tag = subnet.tags.detect { |tag| tag.key == 'Name' }
    {
      name: name_tag ? name_tag.value : nil,
      cidr_block: subnet.cidr_block,
      availability_zone: subnet.availability_zone,
      vpc: vpc_name_tag ? vpc_name_tag.value : nil,
      ensure: :present,
      region: region,
    }
  end

  def exists?
    Puppet.info("Checking if subnet #{name} exists")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating subnet #{name}")
    ec2 = ec2_client(resource[:region])
    vpc_response = ec2.describe_vpcs(filters: [
      {name: "tag:Name", values: [resource[:vpc]]},
    ])
    fail("Multiple VPCs with name #{resource[:vpc]}") if vpc_response.data.vpcs.count > 1
    response = ec2.create_subnet(
      cidr_block: resource[:cidr_block],
      availability_zone: resource[:availability_zone],
      vpc_id: vpc_response.data.vpcs.first.vpc_id,
    )
    ec2.create_tags(
      resources: [response.data.subnet.subnet_id],
      tags: [{key: 'Name', value: name}]
    )
  end

  def destroy
    Puppet.info("Deleting subnet #{name}")
    ec2 = ec2_client(resource[:region])
    response = ec2.describe_subnets(filters: [
      {name: 'tag:Name', values: [name]},
    ])
    fail("Multiple subnets with name #{name}. Not deleting.") if response.data.subnets.count > 1
    response.data.subnets.each do |subnet|
      ec2.delete_subnet(
        subnet_id: subnet.subnet_id
      )
    end
  end
end

