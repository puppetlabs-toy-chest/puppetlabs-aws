require_relative '../../puppet_x/puppetlabs/property/tag.rb'
require_relative '../../puppet_x/puppetlabs/property/region.rb'

Puppet::Type.newtype(:ec2_vpc_subnet) do
  @doc = 'Type representing a VPC Subnet.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the subnet.'
    validate do |value|
      fail 'subnets must have a name' if value == ''
      fail 'name should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:vpc) do
    desc 'The VPC to attach the subnet to.'
    validate do |value|
      fail 'vpc should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:region, :parent => PuppetX::Property::AwsRegion) do
    desc 'The region in which to launch the subnet.'
  end

  newproperty(:cidr_block) do
    desc 'The IP address range for the subnet.'
    validate do |value|
      fail 'cidr_block should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:availability_zone) do
    desc 'The availability zone in which to launch the subnet.'
    validate do |value|
      fail 'availability_zone should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:tags, :parent => PuppetX::Property::AwsTag) do
    desc 'Tags to assign to the subnet.'
  end

  newproperty(:route_table) do
    desc 'The route table to attach to the subnet.'
    validate do |value|
      fail 'route_table should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:map_public_ip_on_launch) do
    desc 'Indicates whether instances launched in this subnet receive a public IP address.'
    defaultto :false
    newvalues(:true, :false)
    def insync?(is)
      is.to_s == should.to_s
    end
  end

  newproperty(:id)

  autorequire(:ec2_vpc) do
    self[:vpc]
  end

  autorequire(:ec2_vpc_routetable) do
    self[:route_table]
  end
end
