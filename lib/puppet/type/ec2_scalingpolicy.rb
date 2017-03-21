require_relative '../../puppet_x/puppetlabs/property/region.rb'

Puppet::Type.newtype(:ec2_scalingpolicy) do
  @doc = 'Type representing an EC2 scaling policy.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the scaling policy.'
    validate do |value|
      fail 'Scaling policies must have a name' if value == ''
      fail 'name should be a String' unless value.is_a?(String)
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

  newproperty(:region, :parent => PuppetX::Property::AwsRegion) do
    desc 'The region in which to launch the policy.'
  end

  newproperty(:adjustment_type) do
    desc 'The type of policy.'
    validate do |value|
      fail 'adjustment_type should not contain spaces' if value =~ /\s/
      fail 'adjustment_type should not be blank' if value == ''
      fail 'adjustment_type should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:auto_scaling_group) do
    desc 'The auto scaling group to attach the policy to.'
    validate do |value|
      fail 'auto_scaling_group cannot be blank' if value == ''
      fail 'auto_scaling_group should be a String' unless value.is_a?(String)
    end
  end

  autorequire(:ec2_autoscalinggroup) do
    self[:auto_scaling_group]
  end
end
