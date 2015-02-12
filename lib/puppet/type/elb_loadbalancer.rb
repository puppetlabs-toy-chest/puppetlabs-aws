require_relative '../../puppet_x/puppetlabs/property/tag.rb'

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

  newproperty(:availability_zones, :array_matching => :all) do
    desc 'the availability zones in which to launch the load balancer'
  end

  newproperty(:instances, :array_matching => :all) do
    desc 'the instances to associate with the load balancer'
  end

  newproperty(:listeners, :array_matching => :all) do
    desc 'the ports and protocols the load balancer listens to'
    def insync?(is)
      normalise(is).to_set == normalise(should).to_set
    end
    def normalise(listeners)
      listeners.collect do |obj|
        obj.each { |k,v| obj[k] = v.to_s.downcase }
      end
    end
  end

  newparam(:tags, :parent => PuppetX::Property::AwsTag) do
    desc 'the tags for the load balancer'
  end

  autorequire(:ec2_instance) do
    instances = self[:instances]
    instances.is_a?(Array) ? instances : [instances]
  end

end
