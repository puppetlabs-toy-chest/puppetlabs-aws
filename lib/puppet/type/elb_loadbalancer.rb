require_relative '../../puppet_x/puppetlabs/property/tag.rb'

Puppet::Type.newtype(:elb_loadbalancer) do
  @doc = 'Type representing an ELB load balancer.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the load balancer.'
    validate do |value|
      fail 'Load Balancers must have a name' if value == ''
    end
  end

  newproperty(:region) do
    desc 'The region in which to launch the load balancer.'
    validate do |value|
      fail 'region must not contain spaces' if value =~ /\s/
    end
  end

  newproperty(:availability_zones, :array_matching => :all) do
    desc 'The availability zones in which to launch the load balancer.'
  end

  newproperty(:instances, :array_matching => :all) do
    desc 'The instances to associate with the load balancer.'
  end

  newproperty(:listeners, :array_matching => :all) do
    desc 'The ports and protocols the load balancer listens to.'
    def insync?(is)
      normalise(is).to_set == normalise(should).to_set
    end
    def normalise(listeners)
      listeners.collect do |obj|
        obj.each { |k,v| obj[k] = v.to_s.downcase }
      end
    end
    validate do |value|
      value = [value] unless value.is_a?(Array)
      fail "you must provide a set if listeners for the load balancer" if value.empty?
      value.each do |listener|
        ['protocol', 'load_balancer_port', 'instance_protocol', 'instance_port'].each do |key|
          fail "listeners must include #{key}" unless listener.keys.include?(key)
        end
      end
    end
  end

  newproperty(:tags, :parent => PuppetX::Property::AwsTag) do
    desc 'The tags for the load balancer.'
  end

  autorequire(:ec2_instance) do
    instances = self[:instances]
    instances.is_a?(Array) ? instances : [instances]
  end

end
