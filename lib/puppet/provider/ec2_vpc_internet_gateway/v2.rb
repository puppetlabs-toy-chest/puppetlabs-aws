require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:ec2_vpc_internet_gateway).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    regions.collect do |region|
      response = ec2_client(region: region).describe_internet_gateways()
      gateways = []
      response.data.internet_gateways.each do |gateway|
        hash = gateway_to_hash(region, gateway)
        gateways << new(hash) if hash[:name]
      end
      gateways
    end.flatten
  end

  read_only(:region)

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region
      end
    end
  end

  def self.gateway_to_hash(region, gateway)
    name_tag = gateway.tags.detect { |tag| tag.key == 'Name' }
    {
      name: name_tag ? name_tag.value : nil,
      vpc_ids: gateway.attachments.map(&:vpc_id),
      id: gateway.internet_gateway_id,
      ensure: :present,
      region: region,
    }
  end

  def exists?
    Puppet.info("Checking if internet gateway #{name} exists")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating internet gateway #{name}")
    ec2 = ec2_client(region: resource[:region])
    vpc_response = ec2.describe_vpcs(filters: [
      {name: "tag:Name", values: resource[:vpcs]},
    ])
    response = ec2.create_internet_gateway()
    id = response.data.internet_gateway.internet_gateway_id
    vpc_response.data.vpcs.each do |vpc|
      ec2.attach_internet_gateway(
        internet_gateway_id: id,
        vpc_id: vpc.vpc_id,
      )
    end
    ec2.create_tags(
      resources: [id],
      tags: [{key: 'Name', value: name}]
    )
  end

  def destroy
    Puppet.info("Deleting internet gateway #{name}")
    ec2 = ec2_client(region: resource[:region])
    response = ec2.describe_internet_gateways(filters: [
      {name: 'tag:Name', values: [name]},
    ])
    fail("Multiple gateways with name #{name}. Not deleting.") if response.data.internet_gateways.count > 1
    response.data.internet_gateways.each do |gateway|
      gateway.attachments.each do |vpc|
        ec2.detach_internet_gateway(
          internet_gateway_id: gateway.internet_gateway_id,
          vpc_id: vpc.vpc_id,
        )
      end
      ec2.delete_internet_gateway(internet_gateway_id: gateway.internet_gateway_id)
    end
  end
end

