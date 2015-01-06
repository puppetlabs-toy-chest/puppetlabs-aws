Puppet::Type.newtype(:ec2_vpc_vpn_gateway) do
  @doc = 'a type representing a VPN gateway'

  ensurable

  newparam(:name, namevar: true) do
    desc 'the name of the VPN gateway'
    validate do |value|
      fail 'VPN gateways must have a name' if value == ''
    end
  end

  newproperty(:tags) do # TODO
    desc 'the tags to assign to the VPN gateway'
  end

  newproperty(:vpc) do
    desc 'the VPN to attach the VPN gateway to'
  end

  newproperty(:region) do
    desc 'the region in which to launch the VPN gateway'
    validate do |value|
      fail 'region should not contain spaces' if value =~ /\s/
    end
  end

  newproperty(:availability_zone) do
    desc 'the availability zone in which to launch the VPN gateway'
  end

  newproperty(:type) do
    desc 'the type of customer gateway, defaults to ipsec.1'
    defaultto 'ipsec.1'
    validate do |value|
      unless value =~ /^ipsec\.1$/
        raise ArgumentError , "'%s' is not a valid type" % value
      end
    end
  end

  autorequire(:ec2_vpc) do
   self[:vpc]
  end
end
