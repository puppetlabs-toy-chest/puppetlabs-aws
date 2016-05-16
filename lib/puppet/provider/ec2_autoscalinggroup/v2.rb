require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:ec2_autoscalinggroup).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws
  confine feature: :retries

  mk_resource_methods
  remove_method :tags=

  def self.instances
    regions.collect do |region|
      begin
        groups = []
        autoscaling_client(region).describe_auto_scaling_groups.each do |response|
          response.data.auto_scaling_groups.each do |group|
            hash = group_to_hash(region, group)
            groups << new(hash)
          end
        end
        groups
      rescue Timeout::Error, StandardError => e
        raise PuppetX::Puppetlabs::FetchingAWSDataError.new(region, self.resource_type.name.to_s, e.message)
      end
    end.flatten
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region
      end
    end
  end

  read_only(:region)

  def self.group_to_hash(region, group)
    subnet_names = []
    unless group.vpc_zone_identifier.nil? || group.vpc_zone_identifier.empty?
      response = ec2_client(region).describe_subnets(subnet_ids: group.vpc_zone_identifier.to_s.split(','))
      subnet_names = response.data.subnets.collect do |subnet|
        subnet_name_tag = subnet.tags.detect { |tag| tag.key == 'Name' }
        subnet_name_tag ? subnet_name_tag.value : nil
      end.reject(&:nil?)
    end
    tags = {}
    group.tags.each do |tag|
      tags[tag.key] = tag.value
    end
    {
      name: group.auto_scaling_group_name,
      launch_configuration: group.launch_configuration_name,
      availability_zones: group.availability_zones,
      min_size: group.min_size,
      max_size: group.max_size,
      desired_capacity: group.desired_capacity,
      default_cooldown: group.default_cooldown,
      health_check_type: group.health_check_type,
      health_check_grace_period: group.health_check_grace_period,
      new_instances_protected_from_scale_in: group.new_instances_protected_from_scale_in,
      load_balancers: fetch_load_balancers(autoscaling_client(region), group.auto_scaling_group_name),
      instance_count: group.instances.count,
      ensure: :present,
      subnets: subnet_names,
      region: region,
      tags: tags,
    }
  end

  def self.fetch_load_balancers(client, name)
    response = client.describe_load_balancers(auto_scaling_group_name: name)
    response.load_balancers.collect { |lb| lb.load_balancer_name }
  end

  def exists?
    Puppet.info("Checking if auto scaling group #{name} exists in region #{target_region}")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Starting auto scaling group #{name} in region #{target_region}")
    zones = resource[:availability_zones]
    zones = [zones] unless zones.is_a?(Array)

    config = {
      auto_scaling_group_name: name,
      min_size: resource[:min_size],
      max_size: resource[:max_size],
      desired_capacity: resource[:desired_capacity] || resource[:min_size],
      default_cooldown: resource[:default_cooldown],
      health_check_type: resource[:health_check_type],
      health_check_grace_period: resource[:health_check_grace_period],
      new_instances_protected_from_scale_in: resource[:new_instances_protected_from_scale_in],
      availability_zones: zones,
      launch_configuration_name: resource[:launch_configuration],
    }

    if resource[:subnets]
      subnets = resource[:subnets]
      subnets = [subnets] unless subnets.is_a?(Array)
      response = ec2_client(target_region).describe_subnets(filters: [
        {name: 'tag:Name', values: subnets},
      ])
      subnet_ids = response.data.subnets.collect(&:subnet_id)
      config['vpc_zone_identifier'] = subnet_ids.join(',')
    end

    client = autoscaling_client(target_region)

    client.create_auto_scaling_group(config)

    set_tags(client, resource[:tags])

    attach_load_balancers(client, resource[:load_balancers])

    @property_hash[:ensure] = :present
  end

  def min_size=(value)
    autoscaling_client(target_region).update_auto_scaling_group(
      auto_scaling_group_name: name,
      min_size: value,
    )
  end

  def max_size=(value)
    autoscaling_client(target_region).update_auto_scaling_group(
      auto_scaling_group_name: name,
      max_size: value,
    )
  end

  def desired_capacity=(value)
    autoscaling_client(target_region).update_auto_scaling_group(
      auto_scaling_group_name: name,
      desired_capacity: value,
    )
  end

  def default_cooldown=(value)
    autoscaling_client(target_region).update_auto_scaling_group(
      auto_scaling_group_name: name,
      default_cooldown: value,
    )
  end

  def health_check_type=(value)
    autoscaling_client(target_region).update_auto_scaling_group(
      auto_scaling_group_name: name,
      health_check_type: value,
    )
  end

  def health_check_grace_period=(value)
    autoscaling_client(target_region).update_auto_scaling_group(
      auto_scaling_group_name: name,
      health_check_grace_period: value,
    )
  end

  def new_instances_protected_from_scale_in=(value)
    autoscaling_client(target_region).update_auto_scaling_group(
      auto_scaling_group_name: name,
      new_instances_protected_from_scale_in: value,
    )
  end

  def subnets=(value)
    subnets = value.is_a?(Array) ? value : [value]
    response = ec2_client(target_region).describe_subnets(filters: [
      {name: 'tag:Name', values: subnets},
    ])
    subnet_ids = response.data.subnets.collect(&:subnet_id)
    autoscaling_client(target_region).update_auto_scaling_group(
      auto_scaling_group_name: name,
      vpc_zone_identifier: subnet_ids.join(','),
    )
  end

  def availability_zones=(value)
    zones = value.is_a?(Array) ? value : [value]
    autoscaling_client(target_region).update_auto_scaling_group(
      auto_scaling_group_name: name,
      availability_zones: zones,
    )
  end

  def load_balancers=(value)
    should = (value.is_a?(Array) ? value : [value]).to_set
    is = fetch_load_balancers(autoscaling_client(target_region), name).to_set

    to_delete = is - should
    to_add = should - is

    autoscaling_client(target_region).attach_load_balancers(
      auto_scaling_group_name: name,
      load_balancer_names: to_add,
    )
    autoscaling_client(target_region).detach_load_balancers(
      auto_scaling_group_name: name,
      load_balancer_names: to_delete,
    )
  end

  def launch_configuration=(value)
    autoscaling_client(target_region).update_auto_scaling_group(
      auto_scaling_group_name: name,
      launch_configuration_name: value,
    )
  end

  def tags=(value)
    set_tags(autoscaling_client(target_region), value)
  end

  def set_tags(client, tags)
    with_retries(:max_tries => 5) do
      client.create_or_update_tags(
        tags: tags ? tags.map { |k,v| {
          key: k,
          value: v,
          resource_id: name,
          resource_type: 'auto-scaling-group',
          propagate_at_launch: false,
        } } : []
      )
    end
  end

  def attach_load_balancers(client, load_balancers)
    with_retries(:max_tries => 5) do
      client.attach_load_balancers(
        auto_scaling_group_name: name,
        load_balancer_names: load_balancers,
      )
    end
  end

  def destroy
    Puppet.info("Deleting auto scaling group #{name} in region #{target_region}")
    autoscaling_client(target_region).delete_auto_scaling_group(
      auto_scaling_group_name: name,
      force_delete: true,
    )
    @property_hash[:ensure] = :absent
  end
end
