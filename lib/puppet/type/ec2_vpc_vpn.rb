require_relative '../../puppet_x/puppetlabs/property/tag.rb'

Puppet::Type.newtype(:ec2_vpc_vpn) do
  @doc = 'Type representing an AWS Virtual Private Networks.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the VPN.'
    validate do |value|
      fail 'VPNs must have a name' if value == ''
      fail 'name should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:vpn_gateway) do
    desc 'The VPN gateway to attach to the VPN.'
    validate do |value|
      fail 'vpn_gateway should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:customer_gateway) do
    desc 'The customer gateway to attach to the VPN.'
    validate do |value|
      fail 'customer_gateway should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:type) do
    desc 'The type of VPN gateway, defaults to ipsec.1.'
    defaultto 'ipsec.1'
    validate do |value|
      unless value =~ /^ipsec\.1$/
        raise ArgumentError , "'%s' is not a valid type" % value
      end
    end
  end

  newproperty(:routes, :array_matching => :all) do
    desc 'The list of routes for the VPN.'
    validate do |value|
      fail 'routes should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:static_routes) do
    desc 'Whether or not to use static routes, defaults to true.'
    defaultto :true
    newvalues(:true, :false)
    def insync?(is)
      is.to_s == should.to_s
    end
  end

  newproperty(:region) do
    desc 'The region in which to launch the VPN.'
    validate do |value|
      fail 'region should not contain spaces' if value =~ /\s/
      fail 'region should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:tags, :parent => PuppetX::Property::AwsTag) do
    desc 'The tags for the VPN.'
  end

  autorequire(:ec2_vpc_customer_gateway) do
    self[:customer_gateway]
  end

  autorequire(:ec2_vpc_vpn_gateway) do
    self[:vpn_gateway]
  end
end
