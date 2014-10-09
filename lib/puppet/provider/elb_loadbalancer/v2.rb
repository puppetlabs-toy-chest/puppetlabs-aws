require 'aws-sdk-core'

require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:elb_loadbalancer).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    regions.collect do |region|
      region_client = elb_client(region: region)
      response = region_client.describe_load_balancers
      response.data.load_balancer_descriptions.collect do |lb|
        new(load_balancer_to_hash(region, lb))
      end
    end.flatten
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end

  def self.load_balancer_to_hash(region, load_balancer)
    {
      name: load_balancer.load_balancer_name,
      ensure: :present,
      region: region
    }
  end

  def exists?
    Puppet.info("Checking if load balancer #{name} exists in region #{region}")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating load balancer #{name} in region #{resource[:region]}")
    groups = resource[:security_groups]

    if groups.nil?
      security_groups = []
    else
      groups = [groups] unless groups.is_a?(Array)
      response = ec2_client(region: resource[:region]).describe_security_groups(group_names: groups.map(&:title))
      security_groups = response.data.security_groups.map(&:group_id)
    end

    zones = resource[:availability_zones]
    zones = [zones] unless zones.is_a?(Array)

    tags = resource[:tags] ? resource[:tags].map { |k,v| {key: k, value: v} } : []
    elb_client(region: resource[:region]).create_load_balancer(
      load_balancer_name: name,
      listeners: [
        {
          protocol: 'tcp',
          load_balancer_port: 80,
          instance_protocol: 'tcp',
          instance_port: 80,
        },
      ],
      availability_zones: zones,
      security_groups: security_groups,
      tags: tags
    )

    instances = resource[:instances]
    instances = [instances] unless instances.is_a?(Array)

    response = ec2_client(region: resource[:region]).describe_instances(
      filters: [
        {name: 'tag:Name', values: instances},
        {name: 'instance-state-name', values: ['pending', 'running']}
      ]
    )

    instance_ids = response.reservations.map(&:instances).
      flatten.map(&:instance_id)

    instance_input = []
    instance_ids.each do |id|
      instance_input << { instance_id: id }
    end

    elb_client(region: resource[:region]).register_instances_with_load_balancer(
      load_balancer_name: name,
      instances: instance_input
    )
  end

  def destroy
    Puppet.info("Destroying load balancer #{name} in region #{resource[:region]}")
    elb_client(region: resource[:region]).delete_load_balancer(
      load_balancer_name: name,
    )
    @property_hash[:ensure] = :absent
  end
end
