Puppet::Type.newtype(:elb_loadbalancer) do
  @doc = 'type representing an ELB load balancer'

  ensurable

  newparam(:name, namevar: true) do
    desc 'the name of the load balancer'
    validate do |value|
      fail Puppet::Error, 'Should not contains spaces' if value =~ /\s/
      fail Puppet::Error, 'Empty values are not allowed' if value == ''
    end
  end

  newparam(:security_groups) do
    desc 'the security groups to associate the load balancer'
  end

  newparam(:instances) do
    desc 'the instances to associate with the load balancer'
  end

  newparam(:listeners) do
    desc 'the ports and protocols the load balancer listens to'
  end

end
