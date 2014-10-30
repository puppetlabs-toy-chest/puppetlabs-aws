require_relative '../../../puppet_x/puppetlabs/aws.rb'
require "base64"

Puppet::Type.type(:ec2_instance).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    regions.collect do |region|
      response = ec2_client(region).describe_instances(filters: [
        {name: 'instance-state-name', values: ['pending', 'running', 'stopping', 'stopped']}
      ])
      instances = []
      response.data.reservations.each do |reservation|
        reservation.instances.each do |instance|
          hash = instance_to_hash(region, instance)
          instances << new(hash) if hash[:name]
        end
      end
      instances
    end.flatten
  end

  read_only(:instance_id, :instance_type, :region, :user_data, :key_name,
            :availability_zones, :security_groups, :monitoring)

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region
      end
    end
  end

  def self.instance_to_hash(region, instance)
    name_tag = instance.tags.detect { |tag| tag.key == 'Name' }
    monitoring = instance.monitoring.state == "enabled" ? true : false
    tags = {}
    instance.tags.each do |tag|
      tags[tag.key] = tag.value unless tag.key == 'Name'
    end
    {
      name: name_tag ? name_tag.value : nil,
      instance_type: instance.instance_type,
      image_id: instance.image_id,
      instance_id: instance.instance_id,
      monitoring: monitoring,
      key_name: instance.key_name,
      availability_zone: instance.placement.availability_zone,
      ensure: instance.state.name.to_sym,
      tags: tags,
      region: region
    }
  end

  def exists?
    dest_region = resource[:region] if resource
    Puppet.info("Checking if instance #{name} exists in region #{dest_region || region}")
    [:present, :pending, :running].include? @property_hash[:ensure]
  end

  def stopped?
    dest_region = resource[:region] if resource
    Puppet.info("Checking if instance #{name} is stopped in region #{dest_region || region}")
    [:stopping, :stopped].include? @property_hash[:ensure]
  end

  def create
    Puppet.info("Starting instance #{name} in region #{resource[:region]}")
    groups = resource[:security_groups]
    groups = [groups] unless groups.is_a?(Array)

    if stopped?
      restart
    else
      data = resource[:user_data].nil? ? nil : Base64.encode64(resource[:user_data])

      config = {
        image_id: resource[:image_id],
        min_count: 1,
        max_count: 1,
        security_groups: groups,
        instance_type: resource[:instance_type],
        user_data: data,
        placement: {
          availability_zone: resource[:availability_zone]
        },
        monitoring: {
          enabled: resource[:monitoring].to_s,
        }
      }

      key = resource[:key_name] ? resource[:key_name] : false
      config['key_name'] = key if key

      response = ec2_client(resource[:region]).run_instances(config)

      @property_hash[:ensure] = :present

      tags = resource[:tags] ? resource[:tags].map { |k,v| {key: k, value: v} } : []
      tags << {key: 'Name', value: name}
      ec2_client(resource[:region]).create_tags(
        resources: response.instances.map(&:instance_id),
        tags: tags
      )
    end
  end

  def restart
    Puppet.info("Starting instance #{name} in region #{resource[:region]}")
    ec2 = ec2_client(resource[:region])
    instances = ec2.describe_instances(filters: [
      {name: 'tag:Name', values: [name]},
      {name: 'instance-state-name', values: ['stopping', 'stopped']}
    ])
    ec2.start_instances(
      instance_ids: instances.reservations.map(&:instances).
        flatten.map(&:instance_id)
    )
    @property_hash[:ensure] = :present
  end

  def stop
    Puppet.info("Stopping instance #{name} in region #{resource[:region]}")
    ec2 = ec2_client(resource[:region])
    instances = ec2.describe_instances(filters: [
      {name: 'tag:Name', values: [name]},
      {name: 'instance-state-name', values: ['pending', 'running']}
    ])
    ec2.stop_instances(
      instance_ids: instances.reservations.map(&:instances).
        flatten.map(&:instance_id)
    )
    @property_hash[:ensure] = :stopped
  end

  def tags=(value)
    Puppet.info("Updating tags for #{name} in region #{region}")
    ec2_client(resource[:region]).create_tags(
      resources: [instance_id],
      tags: value.collect { |k,v| { :key => k, :value => v } }
    ) unless value.empty?
    missing_tags = tags.keys - value.keys
    ec2_client(resource[:region]).delete_tags(
      resources: [instance_id],
      tags: missing_tags.collect { |k| { :key => k } }
    ) unless missing_tags.empty?
  end

  def destroy
    Puppet.info("Deleting instance #{name} in region #{resource[:region]}")
    instances = ec2_client(resource[:region]).describe_instances(filters: [
      {name: 'tag:Name', values: [name]},
      {name: 'instance-state-name', values: ['pending', 'running', 'stopping', 'stopped']}
    ])
    ec2_client(resource[:region]).terminate_instances(
      instance_ids: instances.reservations.map(&:instances).
        flatten.map(&:instance_id)
    )

    @property_hash[:ensure] = :absent
  end
end

