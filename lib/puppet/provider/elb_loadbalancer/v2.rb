require 'aws-sdk-core'

require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:elb_loadbalancer).provide(:v2) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    region = ENV['AWS_REGION']
    client = PuppetX::Puppetlabs::Aws.elb_client(region: region)
    response = client.describe_load_balancers
    response.data.load_balancer_descriptions.collect do |lb|
      new({
        name: lb.load_balancer_name,
        ensure: :present,
        region: region
      })
    end
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end

  def elb_client
    region = resource[:region] || ENV['AWS_REGION']
    PuppetX::Puppetlabs::Aws.elb_client(region: region)
  end

  def ec2_client
    region = resource[:region] || ENV['AWS_REGION']
    PuppetX::Puppetlabs::Aws.ec2_client(region: region)
  end

  def exists?
    Puppet.info("Checking if load balancer #{name} exists")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating load balancer #{name}")
    groups = resource[:security_groups]

    if groups.nil?
      security_groups = []
    else
      groups = [groups] unless groups.is_a?(Array)
      response = ec2_client.describe_security_groups(group_names: groups.map(&:title))
      security_groups = response.data.security_groups.map(&:group_id)
    end

    zones = resource[:availability_zones]
    zones = [zones] unless zones.is_a?(Array)

    elb_client.create_load_balancer(
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
      security_groups: security_groups
    )

    instances = resource[:instances]
    instances = [instances] unless instances.is_a?(Array)

    response = ec2_client.describe_instances(
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

    elb_client.register_instances_with_load_balancer(
      load_balancer_name: name,
      instances: instance_input
    )
  end

  def destroy
    Puppet.info("Destroying load balancer #{name}")
    elb_client.delete_load_balancer(
      load_balancer_name: name,
    )
    @property_hash[:ensure] = :absent
  end
end
