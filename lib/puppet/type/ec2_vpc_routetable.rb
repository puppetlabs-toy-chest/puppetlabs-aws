require_relative '../../puppet_x/puppetlabs/property/tag.rb'

Puppet::Type.newtype(:ec2_vpc_routetable) do
  @doc = 'Type representing a VPC route table.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the route table.'
    validate do |value|
      fail 'route tables must have a name' if value == ''
    end
  end

  newproperty(:vpc) do
    desc 'VPC to assign the route table to.'
  end

  newproperty(:region) do
    desc 'Region in which to launch the route table.'
    validate do |value|
      fail 'region should not contain spaces' if value =~ /\s/
    end
  end

  newproperty(:routes, :array_matching => :all) do
    desc 'Individual routes for the routing table.'
    def insync?(is)
      is.sort_by { |route| route['gateway'] } == should.sort_by { |route| route['gateway'] }
    end
  end

  newproperty(:tags, :parent => PuppetX::Property::AwsTag) do
    desc 'Tags to assign to the route table.'
  end

  autorequire(:ec2_vpc) do
    self[:vpc]
  end

end
