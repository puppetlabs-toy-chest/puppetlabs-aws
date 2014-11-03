Puppet::Type.newtype(:ec2_vpc_subnet) do
  @doc = 'type representing an EC2 VPC Subnet'

  ensurable

  newparam(:name, namevar: true) do
    desc 'the name of the subnet'
    validate do |value|
      fail Puppet::Error, 'Empty values are not allowed' if value == ''
    end
  end

  newproperty(:cidr_block) do
    desc 'the classless inter-domain routing block for this subnet'
  end

  newproperty(:region) do
    desc 'the region in which to launch the subnet'
  end

  newproperty(:availability_zone) do
    desc 'the availability zone in which to create the subnet'
  end

  newproperty(:vpc) do
    desc 'the vpc to assign this subnet to'
  end

  autorequire(:ec2_vpc) do
    self[:vpc]
  end

end
