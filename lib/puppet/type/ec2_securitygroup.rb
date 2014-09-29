Puppet::Type.newtype(:ec2_securitygroup) do
  @doc = 'type representing an EC2 security group'

  ensurable

  newparam(:name, namevar: true) do
    desc 'the name of the security group'
    validate do |value|
      fail Puppet::Error, 'Empty values are not allowed' if value == ''
    end
  end

  newproperty(:region) do
    desc 'the region in which to launch the security group'
    validate do |value|
      fail Puppet::Error, 'Should not contains spaces' if value =~ /\s/
    end
  end

  newparam(:ingress, :array_mathching => :all) do
    desc 'rules for ingress traffic'
  end

  newproperty(:description) do
    desc 'a short description of the group'
    validate do |value|
      fail Puppet::Error, 'Empty values are not allowed' if value == ''
    end
  end

  autorequire(:ec2_securitygroup) do
    rules = self[:ingress]
    rules = [rules] unless rules.is_a?(Array)
    rules.collect do |rule|
      rule['security_group'] if !rule.nil? and rule.key? 'security_group'
    end
  end
end
