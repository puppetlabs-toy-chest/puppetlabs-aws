require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:ec2_volume).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.tag_hash(volume)
    tags = {}
    volume.tags.each {|tag|
      tags[tag.key] = tag.value
    }
    tags
  end

  def self.instances
    response = ec2_client.describe_volumes

    # Due to the confusing nature of volume naming, only volumes with a 'Name'
    # tag are managed.  As such, here we reduce the working set by detecting
    # Name-tagged volumes for collection.
    named_volumes = response.volumes.select {|volume|
      tags = tag_hash(volume)
      tags.keys.include? 'Name' and tags['Name'].size > 0
    }

    named_volumes.collect {|volume|
      tags = tag_hash(volume)
      volume_name = tags['Name']

      new({
        name: volume_name,
        ensure: :present,
        state: volume.state,
        size: volume.size,
        volume_id: volume.volume_id,
        volume_type: volume.volume_type,
        tags: tags,
        availability_zone: volume.availability_zone,
      })
    }
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end

  read_only(:size, :volume_type, :availability_zone)

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating ec2_volume #{resource[:name]}")

    option_hash = {
      size: resource[:size],
      volume_type: resource[:volume_type],
      availability_zone: resource[:availability_zone],
    }

    response = ec2_client.create_volume(option_hash)

    ec2_client.create_tags({
      resources: [response.volume_id],
      tags: [
        {
          key: 'Name',
          value: resource[:name],
        }
      ]
    })
  end

  def destroy
    ec2_client.delete_volume({
      volume_id: @property_hash[:volume_id]
    })
  end
end

