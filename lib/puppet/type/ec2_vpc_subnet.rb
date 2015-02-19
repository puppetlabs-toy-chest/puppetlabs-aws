require_relative '../../puppet_x/puppetlabs/property/tag.rb'

Puppet::Type.newtype(:ec2_vpc_subnet) do
  @doc = 'Type representing a VPC Subnet.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the subnet.'
    validate do |value|
      fail 'subnets must have a name' if value == ''
    end
  end

  newproperty(:vpc) do
    desc 'The VPC to attach the subnet to.'
  end

  newproperty(:region) do
    desc 'The region in which to launch the subnet.'
    validate do |value|
      fail 'region should not contain spaces' if value =~ /\s/
    end
  end

  newproperty(:cidr_block) do
    desc 'The IP address range for the subnet.'
  end

  newproperty(:availability_zone) do
    desc 'The availability zone in which to launch the subnet.'
  end

  newproperty(:tags, :parent => PuppetX::Property::AwsTag) do
    desc 'Tags to assign to the subnet.'
  end

  newproperty(:route_table) do
    desc 'The route table to attach to the subnet.'
  end

  autorequire(:ec2_vpc) do
    self[:vpc]
  end

  autorequire(:ec2_vpc_routetable) do
    self[:route_table]
  end
end
