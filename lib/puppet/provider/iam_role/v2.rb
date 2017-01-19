require_relative '../../../puppet_x/puppetlabs/aws.rb'

require 'uri'

Puppet::Type.type(:iam_role).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    response = iam_client.list_roles()
    response.roles.collect do |role|
      policy_data = JSON.parse(URI.unescape(role.assume_role_policy_document))
      policy_document = JSON.pretty_generate(policy_data)

      new({
              name: role.role_name,
              ensure: :present,
              path: role.path,
              arn: role.arn,
              policy_document: policy_document,
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
    Puppet.info("Checking if IAM role #{name} exists")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating IAM role #{name}")

    iam_client.create_role({
                               role_name: name,
                               path: resource[:path],
                               assume_role_policy_document: resource[:policy_document]
                           })

    @property_hash[:ensure] = :present
  end

  def get_iam_instance_profiles_for_role(role)
    response = iam_client.list_instance_profiles_for_role({
                                                              role_name: role
                                                          })
    response.data.instance_profiles
  end

  def get_iam_attached_policies_for_role(role)
    response = iam_client.list_attached_role_policies({
                                                          role_name: role
                                                      })
    response.data.attached_policies
  end

  def destroy
    Puppet.info("Deleting IAM role #{name}")

    profiles = get_iam_instance_profiles_for_role(name)

    profiles.each do |profile|
      Puppet.debug("Removing #{name} from instance profile #{profile.instance_profile_name}")

      iam_client.remove_role_from_instance_profile({
                                                       instance_profile_name: profile.instance_profile_name,
                                                       role_name: name
                                                   })
    end

    policies = get_iam_attached_policies_for_role(name)

    policies.each do |policy|
      Puppet.debug("Detaching #{policy.policy_arn} from role #{name}")

      iam_client.detach_role_policy({
                                        role_name: name,
                                        policy_arn: policy.policy_arn
                                    })
    end

    iam_client.delete_role({role_name: name})

    @property_hash[:ensure] = :absent
  end
end
