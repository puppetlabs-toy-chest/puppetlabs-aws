require_relative '../../puppet_x/puppetlabs/property/tag.rb'
require_relative '../../puppet_x/puppetlabs/property/region.rb'

Puppet::Type.newtype(:ec2_vpc_internet_gateway) do
  @doc = 'Type representing an EC2 VPC Internet Gateway.'

  newparam(:name, namevar: true) do
    desc 'The name of the internet gateway.'
    validate do |value|
      fail 'Empty values are not allowed' if value == ''
      fail 'name should be a String' unless value.is_a?(String)
    end
  end

  ensurable

  newproperty(:tags, :parent => PuppetX::Property::AwsTag) do
    desc 'Tags to assign to the internet gateway.'
  end

  newproperty(:region, :parent => PuppetX::Property::AwsRegion) do
    desc 'The region in which to launch the internet gateway.'
  end

  newproperty(:vpc) do
    desc 'The vpc to assign this internet gateway to.'
    validate do |value|
      fail 'vpc should be a String' unless value.is_a?(String)
    end
  end

  autorequire(:ec2_vpc) do
    self[:vpc]
  end
end
