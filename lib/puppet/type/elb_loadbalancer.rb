require_relative '../../puppet_x/puppetlabs/property/tag.rb'
require_relative '../../puppet_x/puppetlabs/property/region.rb'

Puppet::Type.newtype(:elb_loadbalancer) do
  @doc = 'Type representing an ELB load balancer.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the load balancer.'
    validate do |value|
      fail 'Load Balancers must have a name' if value == ''
      fail 'name should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:region, :parent => PuppetX::Property::AwsRegion) do
    desc 'The region in which to launch the load balancer.'
  end

  newproperty(:listeners, :array_matching => :all) do
    desc 'The ports and protocols the load balancer listens to.'

    def insync?(is)
      normal_is = provider.class.normalize_values(is).collect do |obj|
        obj.each { |k,v|
          if v.is_a? String
            obj[k] = v.downcase
          else
            obj[k] = v
          end
        }
      end
      normal_should = provider.class.normalize_values(should).collect do |obj|
        obj.each { |k,v|
          if v.is_a? String
            obj[k] = v.downcase
          else
            obj[k] = v
          end
        }
      end

      # Handle the policy attribute comparison
      #
      # First, discoer the correct policy from the listener to compare, merge
      # the desired policy_attributes into the existing policy_attributes to
      # replace the existing keys with the desired keys, then compare the
      # existing policy_attributes with merge result
      #
      matched_listeners = normal_should.collect do |should_listener|
        # Identify the is_listener that matches this should_listener
        is_listener_match = normal_is.select {|i| i['load_balancer_port'] == should_listener['load_balancer_port']}
        unless is_listener_match and is_listener_match.size > 0
          Puppet.debug("Mathing existing listener was not found for #{should_listener['load_balancer_port']}")
          next
        end
        is_listener = is_listener_match.first

        if should_listener['ssl_certificate_id'] != is_listener['ssl_certificate_id']
          false
        elsif should_listener['policies'] and is_listener['policies']
          is_policies = is_listener['policies']
          should_policies = should_listener['policies']

          merged_policies = provider.class.merge_policies(is_policies, should_policies)
          merged_policies == is_policies
        else
          is_listener == should_listener
        end
      end

      if matched_listeners.length > 0
        not matched_listeners.include? false
      else
        false
      end
    end

    munge do |value|
      provider.class.normalize_values(value)
    end

    validate do |value|
      value = [value] unless value.is_a?(Array)
      fail "you must provide a set of listeners for the load balancer" if value.empty?

      required_listener_keys = ['protocol', 'load_balancer_port', 'instance_protocol', 'instance_port']
      optional_keys = ['ssl_certificate_id', 'policies']
      all_keys = [required_listener_keys, optional_keys].flatten

      value.each do |listener|
        required_listener_keys.each do |key|
          fail "listeners must include #{key}" unless listener.keys.include?(key)
        end

        listener.keys.each do |listener_key|
          unless required_listener_keys.include? listener_key or optional_keys.include? listener_key
            fail "unknown listener option #{listener_key}, must be one of #{all_keys}"
          end
        end

        if /HTTPS/i.match(listener['protocol'])
          unless listener.keys.include? 'ssl_certificate_id'
            fail 'When protocol is HTTPS, ssl_certificate_id must be specified'
          end
        end

        if listener.keys.include? 'policies'
          listener['policies'].each do |listener_policies|

            listener_policies.each do |policy_type, policy_attributes|
              unless provider.class.valid_policy_types.include? policy_type
                fail "Invalid policy type #{policy_type}, must be one of #{provider.class.valid_policy_types}"
              end

              next unless policy_attributes

              valid_attributes = provider.class.valid_policy_attributes(policy_type)
              policy_attributes.each do |attribute_name, attribute_value|
                unless valid_attributes.keys.include? attribute_name
                  fail "Invalid attribute #{attribute_name}, must be one of #{valid_attributes.keys}"
                end

              end
            end

          end
        end

      end
    end
  end

  newproperty(:health_check) do
    desc 'The health check configuration for the load balancer'
    def insync?(is)
      provider.class.normalize_values(is) == provider.class.normalize_values(should)
    end
    validate do |value|
      ['target', 'interval', 'timeout', 'unhealthy_threshold', 'healthy_threshold'].each do |key|
        fail "health_check must include #{key}" unless value.keys.include?(key)
      end
    end
  end

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

  newproperty(:availability_zones, :array_matching => :all) do
    desc 'The availability zones in which to launch the load balancer.'
    def insync?(is)
      is.to_set == should.to_set
    end
  end

  newproperty(:instances, :array_matching => :all) do
    desc 'The instances to associate with the load balancer.'
    validate do |value|
      fail 'instances should be a String' unless value.is_a?(String)
    end
    def insync?(is)
      is.to_set == should.to_set
    end
  end

  newproperty(:scheme) do
    desc 'Whether the load balancer is internal or public facing.'
    defaultto :'internet-facing'
    newvalues(:'internet-facing', :internal)
    def insync?(is)
      is.to_s == should.to_s
    end
  end

  newproperty(:dns_name) do
    desc 'The DNS name of the load balancer'
  end

  validate do
    subnets = self[:subnets] || []
    zones = self[:availability_zones] || []
    fail "You can specify either subnets or availability_zones for the ELB #{self[:name]}" if !zones.empty? && !subnets.empty?
  end

  autorequire(:ec2_instance) do
    instances = self[:instances]
    instances.is_a?(Array) ? instances : [instances]
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
