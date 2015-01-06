Puppet::Type.newtype(:ec2_vpc) do
  @doc = "Manage AWS vpcs"
  newparam(:name)
  ensurable
  newproperty(:id) # TODO
  newproperty(:region)
  newproperty(:cidr_block)
  newproperty(:dhcp_options) # TODO
  autorequire(:ec2_vpc_dhcp_options) do
    self[:dhcp_options]
  end
  newproperty(:instance_tenancy) # TODO
  newproperty(:tags) # TODO
end

