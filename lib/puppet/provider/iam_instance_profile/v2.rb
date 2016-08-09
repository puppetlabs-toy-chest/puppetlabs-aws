require_relative '../../../puppet_x/puppetlabs/aws.rb'

require 'uri'

Puppet::Type.type(:iam_instance_profile).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  read_only(:arn)

  def self.instances
    response = iam_client.list_instance_profiles()
    response.instance_profiles.collect do |instance_profile|
      new({
              name: instance_profile.instance_profile_name,
              ensure: :present,
              path: instance_profile.path,
              arn: instance_profile.arn,
              roles: instance_profile.roles,
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
    Puppet.debug("Checking if IAM instance profile #{name} exists")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating IAM instance profile #{name}")

    iam_client.create_instance_profile({
                                           instance_profile_name: name,
                                           path: resource[:path],
                                       })

    @property_hash[:ensure] = :present
  end

  def roles=(value)
    Puppet.debug("Updating roles for #{name} instance profile")

    value.to_a.each do |role|
      Puppet.debug("Adding #{role} to instance profile #{name}")

      iam_client.add_role_to_instance_profile({
                                                  instance_profile_name: name,
                                                  role_name: role
                                              })
    end

    missing_roles = resource[:roles].to_a - value.to_a
    missing_roles.to_a.each do |role|
      Puppet.debug("Removing #{role} from instance profile #{name}")

      iam_client.remove_role_from_instance_profile({
                                                  instance_profile_name: name,
                                                  role_name: role
                                              })
    end
  end

  def destroy
    Puppet.info("Deleting IAM instance profile #{name}")

    @property_hash[:roles].to_a.each do |role|
      Puppet.debug("Removing #{role.role_name} from instance profile #{name}")

      begin
        iam_client.remove_role_from_instance_profile({
                                                         instance_profile_name: name,
                                                         role_name: role.role_name
                                                     })
      rescue Exception => e
        Puppet.warning("Cannot remove: #{e}")
      end

    end

    iam_client.delete_instance_profile({instance_profile_name: name})

    @property_hash[:ensure] = :absent
  end
end
