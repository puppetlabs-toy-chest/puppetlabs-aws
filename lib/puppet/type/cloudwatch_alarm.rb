Puppet::Type.newtype(:cloudwatch_alarm) do
  @doc = 'type representing an AWS CloudWatch Alarm'

  ensurable

  newparam(:name, namevar: true) do
    desc 'the name of the alarm'
    validate do |value|
      fail 'alarms must have a name' if value == ''
    end
  end

  newproperty(:metric) do
    desc 'the name of the metric to track'
    validate do |value|
      fail 'metric must not be blank' if value == ''
    end
  end

  newproperty(:namespace) do
    desc 'the namespace of the metric to track'
    validate do |value|
      fail 'namespace must not be blank' if value == ''
    end
  end

  newproperty(:statistic) do
    desc 'the statistic to track for the metric'
    validate do |value|
      fail 'statistic must not be blank' if value == ''
    end
  end

  newproperty(:period) do
    desc 'the periodicity of the alarm check'
    validate do |value|
      fail 'period cannot be blank' if value == ''
    end
    def insync?(is)
      is.to_i == should.to_i
    end
  end

  newproperty(:evaluation_periods) do
    desc 'the number of checks to use to confirm the alarm'
    validate do |value|
      fail 'evaluation periods cannot be blank' if value == ''
    end
    def insync?(is)
      is.to_i == should.to_i
    end
  end

  newproperty(:threshold) do
    desc 'the threshold used to trigger the alarm'
    validate do |value|
      fail 'threshold cannot be blank' if value == ''
    end
    def insync?(is)
      is.to_f == should.to_f
    end
  end

  newproperty(:comparison_operator) do
    desc 'the operator to use to test the metric'
    validate do |value|
      fail 'comparison operator must not be blank' if value == ''
    end
  end

  newproperty(:region) do
    desc 'the region in which to launch the instances'
    validate do |value|
      fail 'region should not contain spaces' if value =~ /\s/
      fail 'region should not be blank' if value == ''
    end
  end

  newparam(:dimensions, :array_matching => :all) do
    desc 'the dimensions to filter the alerm by'
  end

  newparam(:alarm_actions, :array_matching => :all) do
    desc 'the actions to trigger when the alarm triggers'
  end

  autorequire(:ec2_scalingpolicy) do
    actions = self[:alarm_actions]
    actions.is_a?(Array) ? actions : [actions]
  end
end
