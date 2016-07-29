require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:iam_group).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    response = iam_client.list_groups()
    response.groups.collect do |group|

      group_data = iam_client.get_group({ group_name: group.group_name })
      member_names = group_data.users.map {|user| user.user_name }

      new({
        name: group.group_name,
        ensure: :present,
        path: group.path,
        members: member_names,
      })
    end
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end

  def exists?
    Puppet.debug("Checking if IAM group #{name} exists")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating IAM group #{name}")
    iam_client.create_group({ group_name: name })
    @property_hash[:ensure] = :present
  end

  def destroy
    Puppet.info("Deleting IAM group #{name}")
    groups = iam_client.list_groups.groups.select { |group| group.group_name == name }
    groups.each do |group|
      iam_client.delete_group({group_name: group.group_name})
    end
    @property_hash[:ensure] = :absent
  end

  def members=(value)
    # First all add missing members to the group
    Array(value).flatten.each {|member|
      unless @property_hash[:members].include? member
        Puppet.info("Adding #{member} to #{name}")
        iam_client.add_user_to_group({
          group_name: name,
          user_name: member
        })
      end
    }

    # Then remove non-specified members from the group
    @property_hash[:members].each {|member|
      unless Array(value).flatten.include? member
        Puppet.info("Removing #{member} from #{name}")
        iam_client.remove_user_from_group({
          group_name: name,
          user_name: member
        })
      end
    }

  end
end

