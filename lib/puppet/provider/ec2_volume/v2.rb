require_relative '../../../puppet_x/puppetlabs/aws'

Puppet::Type.type(:ec2_volume).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    regions.collect do |region|
      ec2 = ec2_client(region)
      begin
        volumes = []
        volume_response = ec2.describe_volumes()
        volume_response.data.volumes.collect do |volume|
          hash = volume_to_hash(region, volume)
          volumes << new(hash) if has_name?(hash)
        end
        volumes
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

  def self.volume_to_hash(region, volume)
    name = name_from_tag(volume)
    attachments = volume.attachments.collect do |att|
      {
        instance_id: att.instance_id,
        device: att.device,
      }
    end
    config = {
      name: name,
      volume_id: volume.volume_id,
      size: volume.size,
      iops: volume.iops,
      volume_type: volume.volume_type,
      availability_zone: volume.availability_zone,
      snapshot_id: volume.snapshot_id,
      ensure: :present,
      region: region,
    }
    config[:attach] = attachments unless attachments.empty?
    config
  end

  def exists?
    Puppet.info("Checking if EC2 volume #{name} exists in region #{target_region}")
    @property_hash[:ensure] == :present
  end

  def create_from_snapshot(config)
    snapshot = resource[:snapshot_id] ? resource[:snapshot_id] : false
    config['snapshot_id'] = snapshot if snapshot
    config
  end

  def ec2
    ec2 = ec2_client(target_region)
    ec2
  end

  def attach_instance(volume_id)
    config = {}
    config[:instance_id] = resource[:attach]["instance_id"]
    config[:volume_id] = volume_id
    config[:device] = resource[:attach]["device"]
    Puppet.info("Attaching Volume #{volume_id} to ec2 instance #{config[:instance_id]}")
    ec2.wait_until(:volume_available, volume_ids: [volume_id])
    ec2.attach_volume(config)
  end

  def create
    Puppet.info("Creating Volume #{name} in region #{target_region}")
    config = {
      size: resource[:size],
      availability_zone: resource[:availability_zone],
      volume_type: resource[:volume_type],
      iops: resource[:iops],
      encrypted: resource[:encrypted],
      kms_key_id: resource[:kms_key_id],
    }

    config = create_from_snapshot(config)
    response = ec2.create_volume(config)

    ec2.create_tags(
      resources: [response.volume_id],
      tags: tags_for_resource
    ) if resource[:tags]

    attach_instance(response.volume_id) if resource[:attach]

    @property_hash[:id] = response.volume_id
    @property_hash[:ensure] = :present
  end

  def destroy
    Puppet.info("Deleting Volume #{name} in region #{target_region}")
    # Detach if in use first
    config = {
      volume_id: volume_id,
      force: true
    }
    ec2.detach_volume(config) unless @property_hash[:attach] == nil
    ec2.wait_until(:volume_available, volume_ids: [volume_id])
    ec2.delete_volume(volume_id: volume_id)
    @property_hash[:ensure] = :absent
  end
end
