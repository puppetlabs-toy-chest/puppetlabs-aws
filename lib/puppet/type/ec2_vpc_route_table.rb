Puppet::Type.newtype(:ec2_vpc_route_table) do
  @doc = 'type representing an EC2 VPC Route Table'

  ensurable

  newparam(:name, namevar: true) do
    desc 'the name of the route table'
    validate do |value|
      fail Puppet::Error, 'Empty values are not allowed' if value == ''
    end
  end

  newproperty(:region) do
    desc 'the region in which to launch the route table'
  end

  newproperty(:vpc) do
    desc 'the vpc to assign this route table to'
  end

  autorequire(:ec2_vpc) do
    self[:vpc]
  end

end
