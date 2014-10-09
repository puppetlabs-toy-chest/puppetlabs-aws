require_relative '../../../puppet_x/puppetlabs/aws.rb'
require "base64"

Puppet::Type.type(:ec2_instance).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    []
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] && resource[:region] == prov.region
        resource.provider = prov
      end
    end
  end

  def self.instance_to_hash(region, instance)
    hash = {}
    name = instance.tags.detect { |tag| tag.key == 'Name' }
    if name
      hash = {
        name: name.value,
        instance_type: instance.instance_type,
        image_id: instance.image_id,
        availability_zone: instance.placement.availability_zone,
        ensure: :present,
        region: region
      }
    end

    hash
  end

  def exists?
    Puppet.info("Checking if instance #{name} exists in region #{resource[:region]}")

    if self.provider == :absent
      response = ec2_client(region: resource[:region]).describe_instances(filters: [
        {name: 'instance-state-name', values: ['pending', 'running']},
        {name: 'tag:Name', values: [resource[:name]]}
      ])

      instances = response.reservations.map(&:instances).flatten
      if ! instances.empty?
        instance = instances.first
        @property_hash = self.class.instance_to_hash(resource[:region], instance)
        provider = self.class.new(@property_hash)
      end
    end

    found = @property_hash[:ensure] == :present
    Puppet.info("Instance #{name} already exists in region #{resource[:region]}") if found
    found
  end

  def create
    Puppet.info("Creating instance #{name} in region #{resource[:region]}")
    groups = resource[:security_groups]
    groups = [groups] unless groups.is_a?(Array)

    data = resource[:user_data].nil? ? nil : Base64.encode64(resource[:user_data])

    response = ec2_client(region: resource[:region]).run_instances(
      image_id: resource[:image_id],
      min_count: 1,
      max_count: 1,
      security_groups: groups,
      instance_type: resource[:instance_type],
      user_data: data,
      placement: {
        availability_zone: resource[:availability_zone]
      }
    )
    tags = resource[:tags].map { |k,v| {key: k, value: v} }
    tags << {key: 'Name', value: name}
    ec2_client(region: resource[:region]).create_tags(
      resources: response.instances.map(&:instance_id),
      tags: tags
    )
  end

  def destroy
    Puppet.info("Deleting instance #{name} in region #{resource[:region]}")
    instances = ec2_client(region: resource[:region]).describe_instances(filters: [
      {name: 'tag:Name', values: [name]},
      {name: 'instance-state-name', values: ['pending', 'running']}
    ])
    ec2_client(region: resource[:region]).terminate_instances(
      instance_ids: instances.reservations.map(&:instances).
        flatten.map(&:instance_id)
    )
  end
end

