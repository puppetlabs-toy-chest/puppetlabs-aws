require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:kms).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws
  mk_resource_methods

  def self.instances
    aliases = get_aliases()

    aliases.collect do |key_alias|
      alias_name = /alias\/(.*)/.match(key_alias.alias_name)[1]
      key_alias_target = key_alias.target_key_id
      next unless key_alias_target

      key_id = key_alias.target_key_id
      kms_key = kms_client.describe_key({key_id: key_id})

      begin
        # There is only ever one policy, and that policy is named default.
        kms_policies = get_policy('default', key_id)
      rescue
        Puppet.warning("Unable to get the policy_names for #{alias_name}")
      end

      next if alias_name =~ %r{^aws/.*$}

      new({
        name: alias_name,
        ensure: :present,
        key_id: kms_key.key_metadata.key_id,
        description: kms_key.key_metadata.description,
        creation_date: kms_key.key_metadata.creation_date,
        deletion_date: kms_key.key_metadata.deletion_date,
        policy: kms_policies,
        arn: kms_key.key_metadata.arn,
      })
    end.compact
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end

  def self.get_policy_names(key_id)
    policy_name_results = kms_client.list_key_policies({
      key_id: key_id
    })
    policy_names = policy_name_results.policy_names

    truncated = policy_name_results.truncated
    marker = policy_name_results.next_marker

    while truncated and marker
      Puppet.debug('KMS policy_names results truncated, proceeding with discovery')
      response = kms_client.list_key_policies({
        key_id: key_id,
        marker: marker
      })
      response.policy_names.each {|p| policy_names << p }

      truncated = response.truncated
      marker = response.next_marker
    end

    policy_names
  end

  def self.get_aliases
    alias_results = kms_client.list_aliases()
    aliases = alias_results.aliases

    truncated = alias_results.truncated
    marker = alias_results.next_marker

    while truncated and marker
      Puppet.debug('KMS alias results truncated, proceeding with discovery')
      response = kms_client.list_aliases({marker: marker})
      response.aliases.each {|a| aliases << a }

      truncated = response.truncated
      marker = response.next_marker
    end

    aliases
  end

  def self.get_policy(policy_name, key_id)
    policy_results = kms_client.get_key_policy({
      key_id: key_id,
      policy_name: policy_name
    })

    policy_data = JSON.parse(URI.unescape(policy_results.policy))
    policy_document = JSON.pretty_generate(policy_data)
    policy_document
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def policy=(value)
    Puppet.debug("Replacing policy on KMS key #{resource[:name]}")
    kms_client.put_key_policy({
      key_id: @property_hash[:key_id],
      policy_name: 'default',
      policy: resource[:policy]
    })
  end

  def create
    Puppet.debug("Creating new KMS key #{resource[:name]}")
    new_key = kms_client.create_key({})
    key_id = new_key.key_metadata.key_id
    alias_name = "alias/#{resource[:name]}"

    kms_client.create_alias({
      alias_name: alias_name,
      target_key_id: key_id,
    })

    kms_client.put_key_policy({
      key_id: key_id,
      policy_name: 'default',
      policy: resource[:policy]
    })
  end

  def destroy
    Puppet.debug("Scheduling deletion KMS key #{resource[:name]}")
    kms_client.schedule_key_deletion({
      key_id: @property_hash[:key_id],
    })
  end
end
