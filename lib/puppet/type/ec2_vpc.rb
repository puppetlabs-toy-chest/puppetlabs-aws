require_relative '../../puppet_x/puppetlabs/property/tag.rb'
require_relative '../../puppet_x/puppetlabs/property/region.rb'

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

  newproperty(:region, :parent => PuppetX::Property::AwsRegion) do
    desc 'The region in which to launch the VPC.'
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

  newproperty(:enable_dns_support) do
    desc 'Enable DNS support for this VPC.'
    defaultto :true
    newvalues(:true, :false)
    def insync?(is)
      is.to_s == should.to_s
    end
  end

  newproperty(:enable_dns_hostnames) do
    desc 'Enable DNS hostnames for this VPC.'
    defaultto :true
    newvalues(:true, :false)
    def insync?(is)
      is.to_s == should.to_s
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
