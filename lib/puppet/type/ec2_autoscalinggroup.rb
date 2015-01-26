Puppet::Type.newtype(:ec2_autoscalinggroup) do
  @doc = 'Type representing an EC2 auto scaling group.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the auto scaling group.'
    validate do |value|
      fail 'Auto scaling groups must have a name' if value == ''
    end
  end

  newproperty(:min_size) do
    desc 'the minimum number of instances in the group.'
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

  newproperty(:region) do
    desc 'The region in which to launch the instances.'
    validate do |value|
      fail 'region should not contain spaces' if value =~ /\s/
      fail 'region should not be blank' if value == ''
    end
  end

  newproperty(:launch_configuration) do
    desc 'The launch configuration to use for the group.'
    validate do |value|
      fail 'launch configuration cannot be blank' if value == ''
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
      fail 'must provide a list of availability zones' if value.empty?
    end
    def insync?(is)
      is.to_set == should.to_set
    end
  end

  autorequire(:ec2_launchconfiguration) do
    self[:launch_configuration]
  end
end
