require_relative '../../../puppet_x/puppetlabs/aws.rb'
require 'retries'

Puppet::Type.type(:ec2_vpc_internet_gateway).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods
  remove_method :tags=

  def self.instances
    regions.collect do |region|
      response = ec2_client(region).describe_internet_gateways()
      gateways = []
      response.data.internet_gateways.each do |gateway|
        hash = gateway_to_hash(region, gateway)
        gateways << new(hash) if hash[:name]
      end
      gateways
    end.flatten
  end

  read_only(:region, :vpcs)

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region
      end
    end
  end

  def self.gateway_to_hash(region, gateway)
    assigned_name = name_from_tag(gateway)
    vpcs = []
    vpc_ids = []
    if assigned_name
      vpc_response = ec2_client(region).describe_vpcs(vpc_ids: gateway.attachments.map(&:vpc_id))
      vpc_response.data.vpcs.each do |vpc|
        vpc_name_tag = vpc.tags.detect { |tag| tag.key == 'Name' }
        if vpc_name_tag
          vpcs << vpc_name_tag.value
          vpc_ids << vpc.vpc_id
        end
      end
    end
    {
      name: assigned_name,
      vpcs: vpcs,
      vpc_ids: vpc_ids,
      id: gateway.internet_gateway_id,
      ensure: :present,
      region: region,
      tags: tags_for(gateway),
    }
  end

  def exists?
    dest_region = resource[:region] if resource
    Puppet.info("Checking if internet gateway #{name} exists in #{dest_region || region}")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating internet gateway #{name} in #{resource[:region]}")
    ec2 = ec2_client(resource[:region])
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

    with_retries(:max_tries => 5) do
      ec2.create_tags(
        resources: [id],
        tags: tags_for_resource,
      )
    end
  end

  def destroy
    region = @property_hash[:region]
    Puppet.info("Deleting internet gateway #{name} in #{region}")
    ec2 = ec2_client(region)
    @property_hash[:vpc_ids].each do |vpc_id|
      ec2.detach_internet_gateway(
        internet_gateway_id: @property_hash[:id],
        vpc_id: vpc_id,
      )
    end
    ec2.delete_internet_gateway(internet_gateway_id: @property_hash[:id])
    @property_hash[:ensure] = :absent
  end
end
