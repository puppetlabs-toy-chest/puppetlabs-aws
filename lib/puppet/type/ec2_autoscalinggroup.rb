Puppet::Type.newtype(:ec2_autoscalinggroup) do
  @doc = 'type representing an EC2 auto scaling group'

  ensurable

  newparam(:name, namevar: true) do
    desc 'the name of the security group'
    validate do |value|
      fail 'Security groups must have a name' if value == ''
    end
  end

  newproperty(:min_size) do
    desc 'the minimum number of instances in the group'
    validate do |value|
      fail 'min_size cannot be blank' if value == ''
    end
    def insync?(is)
      is.to_i == should.to_i
    end
  end

  newproperty(:max_size) do
    desc 'the maximum number of instances in the group'
    validate do |value|
      fail 'min_size cannot be blank' if value == ''
    end
    def insync?(is)
      is.to_i == should.to_i
    end
  end

  newproperty(:region) do
    desc 'the region in which to launch the instances'
    validate do |value|
      fail 'region should not contain spaces' if value =~ /\s/
      fail 'region should not be blank' if value == ''
    end
  end

  newproperty(:launch_configuration) do
    desc 'the launch configuration to use for the group'
    validate do |value|
      fail 'launch configuration cannot be blank' if value == ''
    end
  end

  newparam(:availability_zones, :array_matching => :all) do
    desc 'the availability zones in which to launch the instances'
    validate do |value|
      fail 'must provide a list of availability zones' if value.empty?
    end
  end

  autorequire(:ec2_launchconfiguration) do
    self[:launch_configuration]
  end
end
