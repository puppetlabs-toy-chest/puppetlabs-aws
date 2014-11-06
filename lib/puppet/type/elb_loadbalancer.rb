Puppet::Type.newtype(:elb_loadbalancer) do
  @doc = 'type representing an ELB load balancer'

  ensurable

  newparam(:name, namevar: true) do
    desc 'the name of the load balancer'
    validate do |value|
      fail Puppet::Error, 'Load Balancers must have a name' if value == ''
    end
  end

  newproperty(:region) do
    desc 'the region in which to launch the load balancer'
    validate do |value|
      fail Puppet::Error, 'region must not contain spaces' if value =~ /\s/
    end
  end

  newparam(:security_groups, :array_matching => :all) do
    desc 'the security groups to associate the load balancer'
  end

  newparam(:availability_zones, :array_matching => :all) do
    desc 'the availability zones in which to launch the load balancer'
  end

  newparam(:instances, :array_matching => :all) do
    desc 'the instances to associate with the load balancer'
  end

  newparam(:listeners, :array_matching => :all) do
    desc 'the ports and protocols the load balancer listens to'
  end

  newparam(:tags, :array_matching => :all) do
    desc 'the tags for the securitygroup'
  end

  autorequire(:ec2_instance) do
    instances = self[:instances]
    instances.is_a?(Array) ? instances : [instances]
  end

  autorequire(:ec2_securitygroup) do
    groups = self[:security_groups]
    groups.is_a?(Array) ? groups : [groups]
  end

end
