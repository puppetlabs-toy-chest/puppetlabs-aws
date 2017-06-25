require_relative '../../../puppet_x/puppetlabs/aws.rb'
require_relative '../../../puppet_x/puppetlabs/iam_policy'

require 'uri'

Puppet::Type.type(:iam_policy).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws
  mk_resource_methods

  def self.instances
    policies = PuppetX::Puppetlabs::Iam_policy.get_policies
    policies.collect do |policy|

      policy_document_versions = iam_client.list_policy_versions({
        policy_arn: policy.arn,
        max_items: 1
      })

      policy_version_data = iam_client.get_policy_version({
        policy_arn: policy.arn,
        version_id: policy_document_versions.versions[0].version_id
      })

      policy_data = JSON.parse(URI.unescape(policy_version_data.policy_version.document))
      policy_document = JSON.pretty_generate(policy_data)

      new({
        name: policy.policy_name,
        ensure: :present,
        path: policy.path,
        description: policy.description,
        arn: policy.arn,
        document: policy_document,
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
    Puppet.debug("Checking if IAM policy #{name} exists")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating IAM policy #{name}")
    iam_client.create_policy({
      policy_name: name,
      policy_document: resource[:document],
    })
    @property_hash[:ensure] = :present
  end

  def destroy
    # IAM requires that all policy versions are deleted before the policy can
    # be removed.  Here we discover all policy_versions for the policy and
    # delete them.  The default version is removed with the policy.

    Puppet.info("Deleting IAM policy #{name} at #{@property_hash[:arn]}")

    policy_document_versions = iam_client.list_policy_versions({
      policy_arn: @property_hash[:arn],
    })

    non_defaults = policy_document_versions.versions.select {|version|
      version.is_default_version == false
    }

    non_defaults.each {|policy_version|
      Puppet.debug('Deleting non-default policy version')
      iam_client.delete_policy_version({
        policy_arn: @property_hash[:arn],
        version_id: policy_version.version_id
      })

    }

    iam_client.delete_policy({policy_arn: @property_hash[:arn]})

    @property_hash[:ensure] = :absent
  end

  def document=(value)
    # IAM allows up to 5 managed policies at the time of this writing.  As
    # such, if we are going to modify a policy, that is, to create a new one,
    # then we must first delete an old one.  Here we delete the oldest
    # non-default version in the case that we have reached the limit of 5
    # policy versions.

    policy_document_versions = iam_client.list_policy_versions({
      policy_arn: @property_hash[:arn],
    })

    if policy_document_versions.versions.size == 5
      non_defaults = policy_document_versions.versions.select {|version|
        version.is_default_version == false
      }

      Puppet.debug('Deleting old policy version to make room')
      iam_client.delete_policy_version({
        policy_arn: @property_hash[:arn],
        version_id: non_defaults[-1].version_id
      })
    end

    Puppet.info('Creating new policy version')
    iam_client.create_policy_version({
      policy_arn: @property_hash[:arn],
      policy_document: value,
      set_as_default: true,
    })
  end
end
