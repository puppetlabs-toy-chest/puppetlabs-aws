Puppet::Type.newtype(:ec2_vpc_routetable) do
  @doc = "Manage AWS route tables"
  newparam(:name)
  ensurable
  newproperty(:vpc)
  newproperty(:region) # TODO determine if required
  newproperty(:subnets) # TODO

  newproperty(:routes, :array_matching => :all) do
    desc 'individual routes for the routing table'
    def insync?(is)
      is.sort_by { |route| route['gateway'] } == should.sort_by { |route| route['gateway'] }
    end
  end

  newproperty(:main) do # TODO
    newvalue 'true'
    newvalue 'false'
  end
  newproperty(:tags) # TODO
  newproperty(:propagate_routes_from) # TODO
end

