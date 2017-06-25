Puppet::Type.newtype(:iam_policy_attachment) do
  @doc = 'Type representing IAM policy attachments.'

  autorequire(:iam_group) do
    self[:groups]
  end

  autorequire(:iam_user) do
    self[:users]
  end

  autorequire(:iam_role) do
    self[:roles]
  end

  autorequire(:iam_policy) do
    self[:name]
  end

  newparam(:name, namevar: true) do
    desc 'The name of the policy on which to manage entity attachments.'
    validate do |value|
      fail Puppet::Error, 'Empty policy names are not allowed' if value == ''
    end
  end

  newproperty(:groups, :array_matching => :all) do
    desc 'An array of group names the policy should be attached to'
    def insync?(is)
      if is.is_a?(Array) and @should.is_a?(Array)
        is.sort == @should.sort
      else
        is == @should
      end
    end
  end

  newproperty(:users, :array_matching => :all) do
    desc 'An array of group names the policy should be attached to'
    def insync?(is)
      if is.is_a?(Array) and @should.is_a?(Array)
        is.sort == @should.sort
      else
        is == @should
      end
    end
  end

  newproperty(:roles, :array_matching => :all) do
    desc 'An array of role names the policy should be attached to'
    def insync?(is)
      if is.is_a?(Array) and @should.is_a?(Array)
        is.sort == @should.sort
      else
        is == @should
      end
    end
  end

  newproperty(:arn)
  newparam(:exclusive)
end
