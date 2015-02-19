require_relative '../../puppet_x/puppetlabs/property/tag.rb'

Puppet::Type.newtype(:ec2_vpc_dhcp_options) do
  @doc = 'Type representing a DHCP option set for AWS VPC.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the DHCP options set.'
    validate do |value|
      fail 'DHCP option sets must have a name' if value == ''
    end
  end

  newproperty(:tags, :parent => PuppetX::Property::AwsTag) do
    desc 'Tags for the DHCP option set.'
  end

  newproperty(:region) do
    desc 'The region in which to assign the DHCP option set.'
    validate do |value|
      fail 'region should not contain spaces' if value =~ /\s/
    end
  end

  newproperty(:domain_name) do
    desc 'The domain name for the DHCP options.'
    validate do |value|
      unless value =~ /^[\w\.-]+$/
        fail "'%s' is not a valid domain_name" % value
      end
    end
  end

  newproperty(:domain_name_servers, :array_matching => :all) do
    desc 'A list of domain name servers to use for the DHCP options set.'
  end

  newproperty(:ntp_servers, :array_matching => :all) do
    desc 'A list of NTP servers to use for the DHCP options set.'
  end

  newproperty(:netbios_name_servers, :array_matching => :all) do
    desc 'A list of netbios name servers to use for the DHCP options set.'
  end

  newproperty(:netbios_node_type) do
    desc 'The netbios node type, defaults to 2.'
    defaultto '2'
    munge do |value|
      value.to_s
    end
    validate do |value|
      unless value.to_s =~ /^[1248]$/
        fail "'%s' is not a valid netbios_node_type, can be [1248]" % value
      end
    end
  end
end
