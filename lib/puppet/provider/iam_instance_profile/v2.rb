require_relative '../../../puppet_x/puppetlabs/aws.rb'

require 'uri'

Puppet::Type.type(:iam_instance_profile).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

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
    Puppet.info("Checking if IAM instance profile #{name} exists")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating IAM instance profile #{name}")

    iam_client.create_instance_profile({
                                           instance_profile_name: name,
                                       })

    @property_hash[:ensure] = :present
  end

  def destroy
    Puppet.info("Deleting IAM instnace profile #{name}")

    iam_client.delete_instance_profile({ instance_profile_name: name })

    @property_hash[:ensure] = :absent
  end
end
