require_relative '../../puppet_x/puppetlabs/property/tag.rb'
require_relative '../../puppet_x/puppetlabs/property/region.rb'

Puppet::Type.newtype(:ec2_vpc_customer_gateway) do
  @doc = 'Type representing an AWS VPC customer gateways.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the customer gateway.'
    validate do |value|
      fail 'customer gateways must have a name' if value == ''
      fail 'name should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:ip_address) do
    desc 'The IPv4 address for the customer gateway.'
    validate do |value|
      fail "'%s' is not a valid IPv4 address" % value unless value =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/
    end
  end

  newproperty(:bgp_asn) do
    desc 'The Autonomous System Numbers for the customer gateway.'
    validate do |value|
      fail "'%s' is not a valid BGP ASN" % value unless value.to_s =~ /^\d+$/
    end
  end

  newproperty(:tags, :parent => PuppetX::Property::AwsTag) do
    desc 'The tags for the customer gateway.'
  end

  newproperty(:region, :parent => PuppetX::Property::AwsRegion) do
    desc 'The region in which to launch the customer gateway.'
  end

  newproperty(:type) do
    desc 'The type of customer gateway, defaults to ipsec.1.'
    defaultto 'ipsec.1'
    validate do |value|
      fail "'%s' is not a valid type" % value unless value =~ /^ipsec\.1$/
    end
  end

end
