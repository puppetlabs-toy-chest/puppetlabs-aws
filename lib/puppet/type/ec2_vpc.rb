require_relative '../../puppet_x/puppetlabs/property/tag.rb'

Puppet::Type.newtype(:ec2_vpc) do
  @doc = 'A type representing an AWS VPC.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the VPC.'
    validate do |value|
      fail 'a VPC must have a name' if value == ''
      fail 'name should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:region) do
    desc 'The region in which to launch the VPC.'
    validate do |value|
      fail 'region should not contain spaces' if value =~ /\s/
      fail 'region should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:cidr_block) do
    desc 'The IP range for the VPC.'
  end

  newproperty(:dhcp_options) do
    desc 'The DHCP option set to use for this VPC.'
    validate do |value|
      fail 'dhcp_options should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:instance_tenancy) do
    desc 'The supported tenancy options for instances in this VPC.'
    defaultto 'default'
    newvalues('default', 'dedicated')
  end

  newproperty(:tags, :parent => PuppetX::Property::AwsTag) do
    desc 'The tags to assign to the VPC.'
  end

  autorequire(:ec2_vpc_dhcp_options) do
    self[:dhcp_options]
  end
end
