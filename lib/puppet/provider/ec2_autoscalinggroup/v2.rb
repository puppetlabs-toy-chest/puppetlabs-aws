require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:ec2_autoscalinggroup).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    regions.collect do |region|
      groups = []
      autoscaling_client(region).describe_auto_scaling_groups.each do |response|
        response.data.auto_scaling_groups.each do |group|
          hash = group_to_hash(region, group)
          groups << new(hash)
        end
      end
      groups
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
    {
      name: group.auto_scaling_group_name,
      launch_configuration: group.launch_configuration_name,
      availability_zones: group.availability_zones,
      min_size: group.min_size,
      max_size: group.max_size,
      instance_count: group.instances.count,
      ensure: :present,
      region: region
    }
  end

  def exists?
    dest_region = resource[:region] if resource
    Puppet.info("Checking if auto scaling group #{name} exists in region #{dest_region || region}")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Starting auto scaling group #{name} in region #{resource[:region]}")
    zones = resource[:availability_zones]
    zones = [zones] unless zones.is_a?(Array)
    autoscaling_client(resource[:region]).create_auto_scaling_group(
      auto_scaling_group_name: name,
      min_size: resource[:min_size],
      max_size: resource[:max_size],
      availability_zones: zones,
      launch_configuration_name: resource[:launch_configuration],
    )
    @property_hash[:ensure] = :present
  end

  def min_size=(value)
    autoscaling_client(resource[:region]).update_auto_scaling_group(
      auto_scaling_group_name: name,
      min_size: value,
    )
  end

  def max_size=(value)
    autoscaling_client(resource[:region]).update_auto_scaling_group(
      auto_scaling_group_name: name,
      max_size: value,
    )
  end

  def availability_zones=(value)
    zones = value.is_a?(Array) ? value : [value]
    autoscaling_client(resource[:region]).update_auto_scaling_group(
      auto_scaling_group_name: name,
      availability_zones: zones,
    )
  end

  def launch_configuration=(value)
    autoscaling_client(resource[:region]).update_auto_scaling_group(
      auto_scaling_group_name: name,
      launch_configuration_name: value,
    )
  end

  def destroy
    Puppet.info("Deleting auto scaling group #{name} in region #{resource[:region]}")
    autoscaling_client(resource[:region]).delete_auto_scaling_group(
      auto_scaling_group_name: name,
      force_delete: true,
    )
    @property_hash[:ensure] = :absent
  end
end

