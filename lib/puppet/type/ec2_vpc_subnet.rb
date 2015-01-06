Puppet::Type.newtype(:ec2_vpc_subnet) do
  @doc = 'type representing a VPC Subnet'

  ensurable

  newparam(:name, namevar: true) do
    desc 'the name of the subnet'
    validate do |value|
      fail 'Subnets must have a name' if value == ''
    end
  end

  newproperty(:vpc) do
    desc 'the VPC to attach the subnet to'
  end

  newproperty(:region) do
    desc 'the region in which to launch the subnet'
    validate do |value|
      fail 'region should not contain spaces' if value =~ /\s/
    end
  end

  newproperty(:cidr_block) do
    desc 'the IP address range for the subnet'
  end

  newproperty(:availability_zone) do
    desc 'the availability zone in which to launch the subnet'
  end

  newproperty(:tags) do # TODO
    desc 'tags to assign to the subnet'
  end

  newproperty(:route_table) do
    desc 'the route table to attach to the subnet'
  end

  autorequire(:ec2_vpc) do
    self[:vpc]
  end

  autorequire(:ec2_vpc_route_table) do
    self[:route_table]
  end
end
