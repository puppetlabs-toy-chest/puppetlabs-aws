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

  read_only(:region, :availability_zones, :listeners)

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]  # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov
      end
    end
  end

  def self.load_balancer_to_hash(region, load_balancer)
    instance_ids = load_balancer.instances.map(&:instance_id)
    instance_names = []
    unless instance_ids.empty?
      instances = ec2_client(region).describe_instances(instance_ids: instance_ids).collect do |response|
        response.data.reservations.collect do |reservation|
          reservation.instances.collect do |instance|
            instance
          end
        end.flatten
      end.flatten
      instances.each do |instance|
        name_tag = instance.tags.detect { |tag| tag.key == 'Name' }
        name = name_tag ? name_tag.value : nil
        instance_names << name if name
      end
    end
    listeners = load_balancer.listener_descriptions.collect do |listener|
      {
        'protocol' => listener.listener.protocol,
        'load_balancer_port' => listener.listener.load_balancer_port,
        'instance_protocol' => listener.listener.instance_protocol,
        'instance_port' => listener.listener.instance_port,
      }
    end
    {
      name: load_balancer.load_balancer_name,
      ensure: :present,
      region: region,
      availability_zones: load_balancer.availability_zones,
      instances: instance_names,
      listeners: listeners,
    }
  end

  def exists?
    dest_region = resource[:region] if resource
    Puppet.info("Checking if load balancer #{name} exists in region #{dest_region || region}")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating load balancer #{name} in region #{resource[:region]}")
    zones = resource[:availability_zones]
    zones = [zones] unless zones.is_a?(Array)

    tags = resource[:tags] ? resource[:tags].map { |k,v| {key: k, value: v} } : []
    tags << {key: 'Name', value: name}

    listeners = resource[:listeners]
    listeners = [listeners] unless listeners.is_a?(Array)

    listeners_for_api = listeners.collect do |listener|
      {
        protocol: listener['protocol'],
        load_balancer_port: listener['load_balancer_port'],
        instance_protocol: listener['instanceprotocol'],
        instance_port: listener['instance_port'],
      }
    end

    elb_client(resource[:region]).create_load_balancer(
      load_balancer_name: name,
      listeners: listeners_for_api,
      availability_zones: zones,
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
