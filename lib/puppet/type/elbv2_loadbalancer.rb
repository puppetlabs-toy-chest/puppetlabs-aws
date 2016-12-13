require_relative '../../puppet_x/puppetlabs/property/tag.rb'

Puppet::Type.newtype(:elbv2_loadbalancer) do
  @doc = 'Type representing an ELBv2 load balancer.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the load balancer.'
    validate do |value|
      fail 'Load Balancers must have a name' if value == ''
      fail 'name should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:region) do
    desc 'The region in which to launch the load balancer.'
    validate do |value|
      fail 'region must not contain spaces' if value =~ /\s/
      fail 'region should be a String' unless value.is_a?(String)
    end
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
      fail "you must provide a set of listeners for the load balancer" if value.empty?
      value.each do |listener|
        ['protocol', 'port', 'target_group'].each do |key|
          fail "listeners must include #{key}" unless listener.keys.include?(key)
        end
      end
    end
  end

  newproperty(:arn)
  newproperty(:vpc)

  newproperty(:tags, :parent => PuppetX::Property::AwsTag) do
    desc 'The tags for the load balancer.'
  end

  newproperty(:subnets, :array_matching => :all) do
    desc 'The region in which to launch the load balancer.'
    validate do |value|
      fail 'subnets should be a String' unless value.is_a?(String)
    end
    def insync?(is)
      is.to_set == should.to_set
    end
  end

  newproperty(:security_groups, :array_matching => :all) do
    desc 'The security groups to associate the load balancer (VPC only).'
    validate do |value|
      fail 'security_groups should be a String' unless value.is_a?(String)
    end
    def insync?(is)
      is.to_set == should.to_set
    end
  end

  newproperty(:scheme) do
    desc 'Whether the load balancer is internal or public facing.'
    defaultto :'internet-facing'
    newvalues(:'internet-facing', :internal)
  end

  newproperty(:dns_name) do
    desc 'The DNS name of the load balancer'
  end

  autorequire(:ec2_securitygroup) do
    groups = self[:security_groups]
    groups.is_a?(Array) ? groups : [groups]
  end

  autorequire(:ec2_vpc_subnet) do
    subnets = self[:subnets]
    subnets.is_a?(Array) ? subnets : [subnets]
  end

end
