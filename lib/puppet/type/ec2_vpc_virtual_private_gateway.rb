Puppet::Type.newtype(:ec2_vpc_virtual_private_gateway) do
  @doc = "Manage AWS virtual private gateways"
  newparam(:name)
  ensurable
  newproperty(:tags) # TODO
  newproperty(:vpc)
  autorequire(:ec2_vpc) do
   self[:vpc]
  end
  newproperty(:vpn_type)
  newproperty(:region)
  newproperty(:availability_zone)
end

