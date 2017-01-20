require_relative '../../puppet_x/puppetlabs/property/tag.rb'
require_relative '../../puppet_x/puppetlabs/property/region.rb'
require 'puppet/property/boolean'

Puppet::Type.newtype(:ec2_autoscalinggroup) do
  @doc = 'Type representing an EC2 auto scaling group.'

  ensurable

  validate do
    fail "desired_capacity must be greater than or equal to min_size and less than or equal to max_size" unless self[:desired_capacity].nil? || self[:min_size] <= self[:desired_capacity] || self[:desired_capacity] <= self[:max_size]
  end

  newparam(:name, namevar: true) do
    desc 'The name of the auto scaling group.'
    validate do |value|
      fail 'Auto scaling groups must have a name' if value == ''
      fail 'name should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:min_size) do
    desc 'The minimum number of instances in the group.'
    validate do |value|
      fail 'min_size cannot be blank' if value == ''
    end
    munge do |value|
      value.to_i
    end
  end

  newproperty(:max_size) do
    desc 'The maximum number of instances in the group.'
    validate do |value|
      fail 'min_size cannot be blank' if value == ''
    end
    munge do |value|
      value.to_i
    end
  end

  newproperty(:desired_capacity) do
    desc 'The number of EC2 instances that should be running in the group. This number must be greater than or equal to the minimum size of the group (min_size) and less than or equal to the maximum size of the group (max_size).'
    validate do |value|
      fail 'desired_capacity cannot be blank' if value == ''
    end
    munge do |value|
      value.to_i
    end
  end

  newproperty(:default_cooldown) do
    desc 'The amount of time, in seconds, after a scaling activity completes before another scaling activity can start.'

    defaultto '300'

    validate do |value|
      fail 'default_cooldown cannot be blank' if value == ''
    end
    munge do |value|
      value.to_i
    end
  end

  newproperty(:health_check_type) do
    desc 'The service to use for the health checks.'

    newvalue 'EC2'
    newvalue 'ELB'

    defaultto 'EC2'
  end

  newproperty(:health_check_grace_period) do
    desc 'The amount of time, in seconds, that Auto Scaling waits before checking the health status of an EC2 instance that has come into service. During this time, any health check failures for the instance are ignored. This parameter is required if you are adding an ELB health check.'

    defaultto '300'

    validate do |value|
      fail 'health_check_grace_period cannot be blank' if value == ''
    end
    munge do |value|
      value.to_i
    end
  end

  newproperty(:new_instances_protected_from_scale_in, parent: Puppet::Property::Boolean) do
    desc 'Indicates whether newly launched instances are protected from termination by Auto Scaling when scaling in.'
  end

  newproperty(:region, :parent => PuppetX::Property::AwsRegion) do
    desc 'The region in which to launch the instances.'
  end

  newproperty(:launch_configuration) do
    desc 'The launch configuration to use for the group.'
    validate do |value|
      fail 'launch_configuration cannot be blank' if value == ''
      fail 'launch_configuration should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:instance_count) do
    desc 'The number of instances currently running.'
    validate do |value|
      fail 'instance_count is read only'
    end
  end

  newproperty(:availability_zones, :array_matching => :all) do
    desc 'The availability zones in which to launch the instances.'
    validate do |value|
      fail 'availability_zones should be a String' unless value.is_a?(String)
    end
    def insync?(is)
      is.to_set == should.to_set
    end
  end

  newproperty(:load_balancers, :array_matching => :all) do
    desc 'The load balancers attached to this group.'

    defaultto []

    validate do |value|
      fail 'load_balancers cannot be blank' if value == ''
      fail 'load_balancers should be a String' unless value.is_a?(String)
    end
    def insync?(is)
      is.to_set == should.to_set
    end
  end

  newproperty(:target_groups, :array_matching => :all) do
    desc 'The target groups attached to this group.'
    validate do |value|
      fail 'target_groups cannot be blank' if value == ''
      fail 'target_groups should be a String' unless value.is_a?(String)
    end
    def insync?(is)
      is.to_set == should.to_set
    end
  end

  newproperty(:termination_policies, :array_matching => :all) do
    desc 'The termination policies attached to this group.'
    def insync?(is)
      is.to_set == should.to_set
    end
  end

  newproperty(:subnets, :array_matching => :all) do
    desc 'The subnets to associate the autoscaling group.'
    validate do |value|
      fail 'subnets should be a String' unless value.is_a?(String)
    end
    def insync?(is)
      is.to_set == should.to_set
    end
  end

  newproperty(:tags, :parent => PuppetX::Property::AwsTag) do
    desc 'The tags for the autoscaling group.'
  end

  autorequire(:ec2_launchconfiguration) do
    self[:launch_configuration]
  end

  autorequire(:elb_loadbalancer) do
    lbs = self[:load_balancers]
    lbs.is_a?(Array) ? lbs : [lbs]
  end

  autorequire(:ec2_vpc_subnet) do
    subnets = self[:subnets]
    subnets.is_a?(Array) ? subnets : [subnets]
  end
end
