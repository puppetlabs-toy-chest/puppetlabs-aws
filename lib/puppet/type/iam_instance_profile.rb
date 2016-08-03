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

  newproperty(:roles, :array_matching => :all) do
    desc 'The roles to associate the instance profile.'
    def insync?(is)
      is.to_set == should.to_set
    end
    validate do |value|
      fail 'roles should be a String' unless value.is_a?(String)
    end
  end

  autorequire(:iam_role) do
    roles = self[:roles]
    roles.is_a?(Array) ? roles : [roles]
  end
end
