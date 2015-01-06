Puppet::Type.newtype(:ec2_vpc_internet_gateway) do
  @doc = 'type representing an EC2 VPC Internet Gateway'
  @doc = "Manage AWS internet gateways"

  newparam(:name, namevar: true) do
    desc 'the name of the internet gateway'
    validate do |value|
      fail 'Empty values are not allowed' if value == ''
    end
  end

  ensurable

  newproperty(:tags) # TODO
  newparam(:route_to_main) # TODO

  newproperty(:region) do # TODO work out if this is required
    desc 'the region in which to launch the subnet'
  end

  newproperty(:vpcs, :array_matching => :all) do
    desc 'the vpc to assign this subnet to'
  end

  autorequire(:ec2_vpc) do
    vpcs = self[:vpcs]
    vpcs.is_a?(Array) ? vpcs : [vpcs]
  end
end

