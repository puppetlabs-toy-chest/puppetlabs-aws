Puppet::Type.newtype(:ec2_vpc_vpn) do
  @doc = "Manage AWS Virtual Private Networks"
  newparam(:name)
  ensurable
  newproperty(:virtual_private_gateway)
  autorequire(:ec2_vpc_virtual_private_gateway) do
    self[:virtual_private_gateway]
  end
  newproperty(:customer_gateway)
  autorequire(:ec2_vpc_customer_gateway) do
    self[:customer_gateway]
  end
  newproperty(:type)
  newproperty(:routing)
  newproperty(:static_routes)
  newproperty(:region) # TODO is this required
  newproperty(:tags) # TODO
end

