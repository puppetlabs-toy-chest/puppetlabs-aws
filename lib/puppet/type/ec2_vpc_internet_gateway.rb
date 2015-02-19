require_relative '../../puppet_x/puppetlabs/property/tag.rb'

Puppet::Type.newtype(:ec2_vpc_internet_gateway) do
  @doc = 'Type representing an EC2 VPC Internet Gateway.'

  newparam(:name, namevar: true) do
    desc 'The name of the internet gateway.'
    validate do |value|
      fail 'Empty values are not allowed' if value == ''
    end
  end

  ensurable

  newproperty(:tags, :parent => PuppetX::Property::AwsTag) do
    desc 'Tags to assign to the internet gateway.'
  end

  newproperty(:region) do
    desc 'The region in which to launch the subnet.'
    validate do |value|
      fail 'region should not contain spaces' if value =~ /\s/
    end
  end

  newproperty(:vpcs, :array_matching => :all) do
    desc 'The vpcs to assign this subnet to.'
  end

  autorequire(:ec2_vpc) do
    vpcs = self[:vpcs]
    vpcs.is_a?(Array) ? vpcs : [vpcs]
  end
end
