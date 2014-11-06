require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:elb_loadbalancer).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    regions.collect do |region|
      load_balancers = []
      region_client = elb_client(region)
      region_client.describe_load_balancers.each do |response|
        response.data.load_balancer_descriptions.collect do |lb|
          load_balancers << new(load_balancer_to_hash(region, lb))
        end
      end
      load_balancers
    end.flatten
  end

  read_only(:region, :security_groups, :availability_zones)

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]  # rubocop:disable Lint/AssignmentInCondition
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
    dest_region = resource[:region] if resource
    Puppet.info("Checking if load balancer #{name} exists in region #{dest_region || region}")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating load balancer #{name} in region #{resource[:region]}")
    groups = resource[:security_groups]

    if groups.nil?
      security_groups = []
    else
      groups = [groups] unless groups.is_a?(Array)
      response = ec2_client(resource[:region]).describe_security_groups(group_names: groups.map(&:title))
      security_groups = response.data.security_groups.map(&:group_id)
    end

    zones = resource[:availability_zones]
    zones = [zones] unless zones.is_a?(Array)

    tags = resource[:tags] ? resource[:tags].map { |k,v| {key: k, value: v} } : []
    tags << {key: 'Name', value: name}
    elb_client(resource[:region]).create_load_balancer(
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

    @property_hash[:ensure] = :present

    instances = resource[:instances]
    if ! instances.nil?
      instances = [instances] unless instances.is_a?(Array)
      self.class.add_instances_to_load_balancer(resource[:region], name, instances)
    end
  end

  def self.add_instances_to_load_balancer(region, load_balancer_name, instance_names)
    response = ec2_client(region).describe_instances(
      filters: [
        {name: 'tag:Name', values: instance_names},
        {name: 'instance-state-name', values: ['pending', 'running']}
      ]
    )

    instance_ids = response.reservations.map(&:instances).
      flatten.map(&:instance_id)

    instance_input = []
    instance_ids.each do |id|
      instance_input << { instance_id: id }
    end

    elb_client(region).register_instances_with_load_balancer(
      load_balancer_name: load_balancer_name,
      instances: instance_input
    )
  end

  def destroy
    Puppet.info("Destroying load balancer #{name} in region #{resource[:region]}")
    elb_client(resource[:region]).delete_load_balancer(
      load_balancer_name: name,
    )
    @property_hash[:ensure] = :absent
  end
end
