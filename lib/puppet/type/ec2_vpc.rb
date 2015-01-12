Puppet::Type.newtype(:ec2_vpc) do
  @doc = 'a type representing an AWS VPC'

  ensurable

  newparam(:name, namevar: true) do
    desc 'the name of the VPC'
    validate do |value|
      fail 'a VPC must have a name' if value == ''
    end
  end

  newproperty(:region) do
    desc 'the region in which to launch the VPC'
    validate do |value|
      fail 'region should not contain spaces' if value =~ /\s/
    end
  end

  newproperty(:cidr_block) do
    desc 'the IP range for the VPC'
  end

  newparam(:dhcp_options) do
    desc 'the DHCP option set to use for this VPC'
  end

  newproperty(:instance_tenancy) do
    desc 'the supported tenancy options for instances in this VPC'
    defaultto 'default'
    newvalues('default', 'dedicated')
  end

  newproperty(:tags) do # TODO
    desc 'the tags to assign to the VPC'
  end

  autorequire(:ec2_vpc_dhcp_options) do
    self[:dhcp_options]
  end
end
