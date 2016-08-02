Puppet::Type.newtype(:iam_instance_profile) do
  @doc = 'Type representing IAM instance profiles.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the instance profile to manage.'
    validate do |value|
      fail Puppet::Error, 'Empty instnace profile names are not allowed' if value == ''
    end
  end

  newproperty(:path) do
    desc 'The path of the instance profile.'
    defaultto '/'

    validate do |value|
      unless value =~ /^[^\0]+$/
        raise ArgumentError , "'%s' is not a valid path" % value
      end
    end
  end

  newproperty(:arn)

  newproperty(:roles)
end
