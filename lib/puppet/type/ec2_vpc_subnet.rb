Puppet::Type.newtype(:ec2_vpc_subnet) do
  @doc = "Manage AWS subnets"
  newparam(:name)
  ensurable
  newproperty(:vpc)
  newproperty(:region)
  autorequire(:ec2_vpc) do
    self[:vpc]
  end
  newproperty(:cidr_block)
  newproperty(:availability_zone)
  newparam(:unique_az_in_vpc) do # TODO
    desc "Auto-assign to an AZ not used by any other subnets in this VPC."
  end
  newproperty(:tags) # TODO
  newproperty(:route_table) # TODO
end

