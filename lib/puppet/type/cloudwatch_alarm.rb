Puppet::Type.newtype(:cloudwatch_alarm) do
  @doc = 'Type representing an AWS CloudWatch Alarm.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the alarm.'
    validate do |value|
      fail 'alarms must have a name' if value == ''
      fail 'Name should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:metric) do
    desc 'The name of the metric to track.'
    validate do |value|
      fail 'metric must not be blank' if value == ''
      fail 'metric should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:namespace) do
    desc 'The namespace of the metric to track.'
    validate do |value|
      fail 'namespace must not be blank' if value == ''
      fail 'namespace should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:statistic) do
    desc 'The statistic to track for the metric.'
    validate do |value|
      fail 'statistic must not be blank' if value == ''
      fail 'statistic should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:period) do
    desc 'The periodicity of the alarm check.'
    validate do |value|
      fail 'period cannot be blank' if value == ''
    end
    munge do |value|
      value.to_i
    end
  end

  newproperty(:evaluation_periods) do
    desc 'The number of checks to use to confirm the alarm.'
    validate do |value|
      fail 'evaluation periods cannot be blank' if value == ''
    end
    munge do |value|
      value.to_i
    end
  end

  newproperty(:threshold) do
    desc 'The threshold used to trigger the alarm.'
    validate do |value|
      fail 'threshold cannot be blank' if value == ''
    end
    munge do |value|
      value.to_f
    end
  end

  newproperty(:comparison_operator) do
    desc 'The operator to use to test the metric.'
    validate do |value|
      fail 'comparison_operator must not be blank' if value == ''
      fail 'comparison_operator should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:region) do
    desc 'The region in which to launch the instances.'
    validate do |value|
      fail 'region should not contain spaces' if value =~ /\s/
      fail 'region should not be blank' if value == ''
      fail 'region should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:dimensions, :array_matching => :all) do
    desc 'The dimensions to filter the alarm by.'
    def insync?(is)
      is.to_set == should.to_set
    end
    validate do |value|
      fail 'dimensions should be a Hash' unless value.is_a?(Hash)
    end
  end

  newproperty(:alarm_actions, :array_matching => :all) do
    desc 'The actions to trigger when the alarm triggers.'
    validate do |value|
      fail 'alarm_actions should be a String' unless value.is_a?(String)
    end
  end

  autorequire(:ec2_scalingpolicy) do
    actions = self[:alarm_actions]
    actions.is_a?(Array) ? actions : [actions]
  end
end
