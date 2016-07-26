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
                               assume_role_policy_document: resource[:policy_document]
                           })

    @property_hash[:ensure] = :present
  end

  def destroy
    Puppet.info("Deleting IAM role #{name}")

    iam_client.delete_role({role_name: name})

    @property_hash[:ensure] = :absent
  end
end
