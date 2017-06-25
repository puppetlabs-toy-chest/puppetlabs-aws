Puppet::Type.newtype(:iam_policy) do
  @doc = 'Type representing IAM policy.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the policy to manage.'
    validate do |value|
      fail Puppet::Error, 'Empty policy names are not allowed' if value == ''
    end
  end

  newproperty(:document) do
    desc 'The policy document JSON string'
    isrequired
    validate do |value|
      fail Puppet::Error, 'Policy documents must be JSON strings' unless value.is_a? String
    end

    munge do |value|
      begin
        data = JSON.parse(value)
        JSON.pretty_generate(data)
      rescue
        fail('Document string is not valid JSON')
      end
    end
  end

  newproperty(:arn)
end
