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
    groups = iam_client.list_groups.groups.select { |group| group.group_name == name }
    groups.each do |group|

      # Remove all inline policies from the group
      inline_polcies = iam_client.list_group_policies({group_name: group.group_name}).policy_names
      inline_polcies.each {|policy_name|
        Puppet.debug("Deleting inline policy #{policy_name} from #{group.group_name}")
        iam_client.delete_group_policy({
          group_name: group.group_name,
          policy_name: policy_name,
        })
      }

      # Detach all managed policies from the group
      attached_policies = iam_client.list_attached_group_policies(
        {group_name: group.group_name}
      ).attached_policies.collect(&:policy_arn)

      attached_policies.each {|policy_arn|
        Puppet.debug("Detaching managed policy #{policy_arn} from IAM group #{group.group_name}")
        iam_client.detach_group_policy({
          group_name: group.group_name,
          policy_arn: policy_arn
        })
      }

      # Delete all the members from the group
      @property_hash[:members].each {|member|
        Puppet.debug("Removing user #{member} from IAM group #{group.group_name}")
        iam_client.remove_user_from_group({
          group_name: group.group_name,
          user_name: member
        })
      }

      Puppet.info("Deleting IAM group #{group}")
      iam_client.delete_group({group_name: group.group_name})
    end
    @property_hash[:ensure] = :absent
  end

  def members=(value)
    unless @property_hash[:ensure] == :absent
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

end

