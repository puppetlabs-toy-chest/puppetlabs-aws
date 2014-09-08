Puppet::Type.newtype(:ec2_securitygroup) do
  @doc = 'type representing an EC2 security group'

  ensurable

  newparam(:name, namevar: true) do
    desc 'the name of the security group'
    validate do |value|
      fail Puppet::Error, 'Should not contains spaces' if value =~ /\s/
      fail Puppet::Error, 'Empty values are not allowed' if value == ''
    end
  end

  newparam(:ingress) do
    desc 'rules for ingress traffic'
  end

  newparam(:description) do
    desc 'a short description of the group'
    validate do |value|
      fail Puppet::Error, 'Empty values are not allowed' if value == ''
    end
  end
end
