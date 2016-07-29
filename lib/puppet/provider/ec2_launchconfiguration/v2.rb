require_relative '../../../puppet_x/puppetlabs/aws.rb'
require "base64"

Puppet::Type.type(:ec2_launchconfiguration).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    regions.collect do |region|
      begin
        launch_configs = []
        autoscaling_client(region).describe_launch_configurations.each do |response|
          response.data.launch_configurations.each do |config|
            hash = config_to_hash(region, config)
            launch_configs << new(hash)
          end
        end
        launch_configs
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

  read_only(:region, :image_id, :instance_type, :key_name, :security_groups)

  def self.config_to_hash(region, config)
    # It appears possible to get launch configurations manually to a state where
    # they return the identifier of an invalid or a non-existent security groups
    security_group_names = begin
      group_response = ec2_client(region).describe_security_groups(group_ids: config.security_groups)
      group_response.data.security_groups.collect(&:group_name)
    rescue Aws::EC2::Errors::InvalidGroupIdMalformed, Aws::EC2::Errors::InvalidGroupNotFound
      []
    end
    {
      name: config.launch_configuration_name,
      security_groups: security_group_names,
      instance_type: config.instance_type,
      image_id: config.image_id,
      key_name: config.key_name,
      ensure: :present,
      region: region
    }
  end

  def exists?
    Puppet.debug("Checking if launch configuration #{name} exists in region #{target_region}")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Starting launch configuration #{name} in region #{target_region}")
    groups = resource[:security_groups]
    groups = [groups] unless groups.is_a?(Array)
    groups = groups.reject(&:nil?)

    group_ids = []
    unless groups.empty?
      ec2 = ec2_client(target_region)
      filters = [{name: 'group-name', values: groups}]
      vpc_name = resource[:vpc]
      if vpc_name
        vpc_response = ec2.describe_vpcs(filters: [
          {name: 'tag:Name', values: [vpc_name]}
        ])
        fail("No VPC found called #{vpc_name}") if vpc_response.data.vpcs.count == 0
        vpc_ids = vpc_response.data.vpcs.collect(&:vpc_id)
        filters << {name: 'vpc-id', values: vpc_ids}
      end
      group_response = ec2.describe_security_groups(filters: filters)
      group_ids = group_response.data.security_groups.collect(&:group_id)
    end

    data = resource[:user_data].nil? ? nil : Base64.encode64(resource[:user_data])

    config = {
      launch_configuration_name: name,
      image_id: resource[:image_id],
      security_groups: group_ids,
      instance_type: resource[:instance_type],
      user_data: data,
    }

    key = resource[:key_name] ? resource[:key_name] : false
    config['key_name'] = key if key

    autoscaling_client(target_region).create_launch_configuration(config)

    @property_hash[:ensure] = :present
  end

  def destroy
    Puppet.info("Deleting instance #{name} in region #{target_region}")
    autoscaling_client(target_region).delete_launch_configuration(
      launch_configuration_name: name
    )
    @property_hash[:ensure] = :absent
  end
end
