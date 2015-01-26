Puppet::Type.newtype(:ec2_scalingpolicy) do
  @doc = 'Type representing an EC2 scaling policy.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the scaling policy.'
    validate do |value|
      fail 'Scaling policies must have a name' if value == ''
    end
  end

  newproperty(:scaling_adjustment) do
    desc 'The amount to adjust the size of the group by.'
    validate do |value|
      fail 'scaling adjustment cannot be blank' if value == ''
    end
    munge do |value|
      value.to_i
    end
  end

  newproperty(:region) do
    desc 'The region in which to launch the policy.'
    validate do |value|
      fail 'region should not contain spaces' if value =~ /\s/
      fail 'region should not be blank' if value == ''
    end
  end

  newproperty(:adjustment_type) do
    desc 'The type of policy.'
    validate do |value|
      fail 'adjustment type should not contain spaces' if value =~ /\s/
      fail 'adjustment type should not be blank' if value == ''
    end
  end

  newproperty(:auto_scaling_group) do
    desc 'The auto scaling group to attach the policy to.'
    validate do |value|
      fail 'auto scaling group cannot be blank' if value == ''
    end
  end

  autorequire(:ec2_autoscalinggroup) do
    self[:auto_scaling_group]
  end
end
