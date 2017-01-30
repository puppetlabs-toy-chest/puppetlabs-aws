Puppet::Type.newtype(:kms) do
  @doc = 'Type representing a KMS key instance.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The alias name of the KMS key to manage.'
    validate do |value|
      fail Puppet::Error, 'Empty usernames are not allowed' if value == ''
    end
  end

  newproperty(:arn)
  newproperty(:key_id)
  newproperty(:enabled)
  newproperty(:description)
  newproperty(:creation_date)
  newproperty(:deletion_date)
  newproperty(:policy) do
    desc 'The policy document JSON string'
    isrequired
    validate do |value|
      fail Puppet::Error, 'Policy documents must be JSON strings' unless value.is_a? String
      JSON.parse(value)
    end

    munge do |value|
      begin
        data = JSON.parse(value)
        JSON.pretty_generate(data)
      rescue
        fail('Document string is not valid JSON')
      end
    end

    def insync?(is)
      one = JSON.parse(is)
      two = JSON.parse(should)
      provider.class.normalize_hash(one) == provider.class.normalize_hash(two)
    end
  end

end
