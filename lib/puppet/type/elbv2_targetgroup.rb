require_relative '../../puppet_x/puppetlabs/property/tag.rb'

Puppet::Type.newtype(:elbv2_targetgroup) do
  @doc = 'Type representing an ELBv2 target group.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the target group.'
    validate do |value|
      fail 'Target Groups must have a name' if value == ''
      fail 'name should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:region) do
    desc 'The region in which to launch the load balancer.'
    validate do |value|
      fail 'region must be specified' unless value
      fail 'region must not contain spaces' if value =~ /\s/
      fail 'region should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:protocol) do
    desc 'Protocol to use for routing traffic to targets (HTTP/HTTPS)'
    newvalues(:HTTP, :HTTPS)
    validate do |value|
      file 'protocol must be specified' unless value
      fail 'Invalid protocol - must be HTTP or HTTPS' unless value =~ /^HTTPS?$/
    end
  end

  newproperty(:port) do
    desc 'Port on which the targets receive traffic'
    validate do |value|
      file 'Target port must be specified' unless value
    end
    munge do |value|
      value.to_i
    end
  end

#  newproperty(:vpc) do
#    desc 'Id of the virtual private cloud (VPC)'
#    validate do |value|
#      fail 'VPC ID must be specified' unless value
#    end
#  end

  newproperty(:load_balancers) do
    desc 'The load balancer to assign this target group too'
  end

  newproperty(:health_check_success_codes) do
    desc 'HTTP state codes to use when checking for a successful response from a target'
  end

  newproperty(:health_check_path) do
    desc 'Path to request when performing health checks'
  end

  newproperty(:health_check_port) do
    desc 'The port the elb uses when performing health checks'
    validate do |value|
      fail 'Invalid health check port - must be traffic-port or port number' unless value.downcase =~ /^(traffic-port|[0-9]+)$/
    end
  end

  newproperty(:health_check_protocol) do
    desc 'The protocol the elb uses when performing health checks on targets (HTTP/HTTPS)'
    newvalues(:HTTP, :HTTPS)
    validate do |value|
      fail 'Invalid health check protocol - must be HTTP or HTTPS' unless value.upcase =~ /^HTTPS?$/
    end
  end

  newproperty(:health_check_interval) do
    desc 'Approximate time (seconds) between health checks'
    validate do |value|
      fail 'health_check_interval must be a number' unless value =~ /^[0-9]+$/
    end
    munge do |value|
      value.to_i
    end
  end

  newproperty(:health_check_timeout) do
    desc 'Amount of time (seconds) during which no response means a failed health check'
    validate do |value|
      fail 'health_check_timeout must be a number' unless value =~ /^[0-9]+$/
    end
    munge do |value|
      value.to_i
    end
  end

  newproperty(:healthy_threshold) do
    desc 'Number of consecutive health check successes required before considering an unhealthy target healthy'
    validate do |value|
      fail 'healthy_threshold must be a number' unless value =~ /^[0-9]+$/
    end
    munge do |value|
      value.to_i
    end
  end

  newproperty(:unhealthy_threshold) do
    desc 'Number of consecutive health check failures required before considering a healthy target unhealthy'
    validate do |value|
      fail 'unhealthy_threshold must be a number' unless value =~ /^[0-9]+$/
    end
    munge do |value|
      value.to_i
    end
  end

  newproperty(:deregistration_delay) do
    desc 'Amount of time (seconds) for elb to wait before changing state of deregistering target from draining to unused (0-3600)'
    validate do |value|
      fail 'deregistration_delay must be a number' unless value =~ /^[0-9]+$/
      fail 'Invalid deregistration time - must be between 0 and 3600' if value.to_i < 0 or value.to_i > 3600
    end
    munge do |value|
      value.to_i
    end
  end

  newproperty(:stickiness, parent: Puppet::Property::Boolean) do
    desc 'Indicates whether sticky sessions are enabled'
  end

  newproperty(:stickiness_duration) do
    desc 'Amount of time (seconds) where requests should be routed to the same target (1-604800)'
    validate do |value|
      fail 'stickiness_duration must be a number' unless value =~ /^[0-9]+$/
      fail 'Invalid stickiness duration - must be between 1 and 604800' if value.to_i < 1 or value.to_i > 604800
    end
    munge do |value|
      value.to_i
    end
  end

  newproperty(:tags, :parent => PuppetX::Property::AwsTag) do
    desc 'The tags for the instance.'
  end

  autorequire(:ec2_vpc) do
    self[:vpc]
  end

end
