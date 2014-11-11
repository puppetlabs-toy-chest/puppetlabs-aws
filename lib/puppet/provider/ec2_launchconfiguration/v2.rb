require_relative '../../../puppet_x/puppetlabs/aws.rb'
require "base64"

Puppet::Type.type(:ec2_launchconfiguration).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    regions.collect do |region|
      launch_configs = []
      autoscaling_client(region).describe_launch_configurations.each do |response|
        response.data.launch_configurations.each do |config|
          hash = config_to_hash(region, config)
          launch_configs << new(hash)
        end
      end
      launch_configs
    end.flatten
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region
      end
    end
  end

  read_only(:region, :image_id, :instance_type, :key_name, :security_groups)

  def self.config_to_hash(region, config)
    {
      name: config.launch_configuration_name,
      security_groups: config.security_groups,
      instance_type: config.instance_type,
      image_id: config.image_id,
      key_name: config.key_name,
      ensure: :present,
      region: region
    }
  end

  def exists?
    dest_region = resource[:region] if resource
    Puppet.info("Checking if launch configuration #{name} exists in region #{dest_region || region}")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Starting launch configuration #{name} in region #{resource[:region]}")
    groups = resource[:security_groups]
    groups = [groups] unless groups.is_a?(Array)
    groups = groups.reject(&:nil?)

    data = resource[:user_data].nil? ? nil : Base64.encode64(resource[:user_data])

    config = {
      launch_configuration_name: name,
      image_id: resource[:image_id],
      security_groups: groups,
      instance_type: resource[:instance_type],
      user_data: data,
    }

    key = resource[:key_name] ? resource[:key_name] : false
    config['key_name'] = key if key

    autoscaling_client(resource[:region]).create_launch_configuration(config)

    @property_hash[:ensure] = :present
  end

  def destroy
    Puppet.info("Deleting instance #{name} in region #{resource[:region]}")
    autoscaling_client(resource[:region]).delete_launch_configuration(
      launch_configuration_name: name
    )
    @property_hash[:ensure] = :absent
  end
end
