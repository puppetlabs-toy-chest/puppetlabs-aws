Puppet::Type.newtype(:ec2_vpc_routetable) do
  @doc = 'type representing a VPC route table'

  ensurable

  newparam(:name, namevar: true) do
    desc 'the name of the route table'
    validate do |value|
      fail 'route tables must have a name' if value == ''
    end
  end

  newproperty(:vpc) do
    desc 'VPC to assign the route table to'
  end

  newproperty(:region) do
    desc 'region in which to launch the route table'
  end

  newproperty(:routes, :array_matching => :all) do
    desc 'individual routes for the routing table'
    def insync?(is)
      is.sort_by { |route| route['gateway'] } == should.sort_by { |route| route['gateway'] }
    end
  end

  newproperty(:tags) do # TODO
    desc 'tags to assign to the route table'
  end

end
