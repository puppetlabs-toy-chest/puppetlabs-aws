Puppet::Type.newtype(:ecs_service) do
  @doc = 'Type representing ECS services.'

  ensurable

  autorequire(:ecs_cluster) do
    self[:cluster]
  end

  autorequire(:ecs_task_definition) do
    self[:task_definition]
  end

  newparam(:name, namevar: true) do
    desc 'The name of the cluster to manage.'
    validate do |value|
      fail Puppet::Error, 'Empty usernames are not allowed' if value == ''
    end
  end

  newproperty(:arn)
  newproperty(:status)
  newproperty(:load_balancers) do
    munge do |value|
      provider.class.normalize_values(value)
    end
  end

  newproperty(:desired_count) do
    isrequired
    validate do |value|
      fail Puppet::Error, 'desired_count must be an integer' unless value.is_a? Integer
    end
  end
  newproperty(:running_count)
  newproperty(:pending_count)
  newproperty(:task_definition) do
    isrequired
  end
  newproperty(:deployment_configuration) do
    munge do |value|
      provider.class.normalize_values(value)
    end

    def insync?(is)
      provider.class.normalize_values(should) == provider.class.normalize_values(is)
    end
  end
  newproperty(:role_arn)
  newproperty(:cluster) do
    isrequired
    defaultto "default"
  end
end

