Puppet::Type.newtype(:iam_group) do
  @doc = 'Type representing IAM groups.'

  autorequire(:iam_user) do
    self[:members]
  end

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the group to manage.'
    validate do |value|
      fail Puppet::Error, 'Empty group names are not allowed' if value == ''
    end
  end

  newproperty(:members, :array_matching => :all) do
    desc 'An array of member user names to include in the group'
    isrequired
    def insync?(is)
      if is.is_a?(Array) and @should.is_a?(Array)
        is.sort == @should.sort
      else
        is == @should
      end
    end
  end

end
