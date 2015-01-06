Puppet::Type.newtype(:ec2_vpc_customer_gateway) do
  @doc = 'type representing an AWS VPC customer gateways'

  ensurable

  newparam(:name, namevar: true) do
    desc 'the name of the customer gateway'
    validate do |value|
      fail 'customer gateways must have a name' if value == ''
    end
  end

  newproperty(:ip_address) do
    desc 'the IPv4 address for the customer gatewat'
    validate do |value|
      fail "'%s' is not a valid IPv4 address" % value unless value =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/
    end
  end

  newproperty(:bgp_asn) do
    desc 'The Autonomous System Numbers for the customer gateway'
    validate do |value|
      fail "'%s' is not a valid BGP ASN" % value unless value.to_s =~ /^\d+$/
    end
  end

  newproperty(:tags) do
    desc 'the tags for the customer gateway'
  end

  newproperty(:region) do
    desc 'the region in which to launch the customer gateway'
    validate do |value|
      fail 'region should not contain spaces' if value =~ /\s/
    end
  end

  newproperty(:type) do
    desc 'the type of customer gateway, defaults to ipsec.1'
    defaultto 'ipsec.1'
    validate do |value|
      fail "'%s' is not a valid type" % value unless value =~ /^ipsec\.1$/
    end
  end

end
