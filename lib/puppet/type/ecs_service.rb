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

  newproperty(:arn) do
    desc 'Read-only unique AWS resource name assigned to the ECS service'
  end

  newproperty(:status) do
    desc 'Read-only status of the ECS service'
  end

  newproperty(:load_balancers, :array_matching => :all) do
    desc 'An array of hashes representing load balancers assigned to a service.'
    munge do |value|
      provider.class.normalize_values(value)
    end

    def insync?(is)
      provider.class.normalize_values(should) == provider.class.normalize_values(is)
    end
  end

  newproperty(:desired_count) do
    desc 'A count of this service that should be running'

    isrequired
    validate do |value|
      fail Puppet::Error, 'desired_count must be an integer' unless value.is_a? Integer
    end
  end
  newproperty(:running_count) do
    desc 'Read-only count of the running ECS tasks on the cluster'
  end

  newproperty(:pending_count) do
    desc 'Read-only count of the tasks in a pending state on the cluster'
  end

  newproperty(:task_definition) do
    isrequired
  end
  newproperty(:deployment_configuration) do
    desc 'The deployment configuration of the service.

    A hash with the keys of "maximum_percent" and "minimum_healthy_percent"
    with integer values represnting percent.'

    munge do |value|
      provider.class.normalize_values(value)
    end

    def insync?(is)
      provider.class.normalize_values(should) == provider.class.normalize_values(is)
    end
  end

  newproperty(:role) do
    desc 'The short name of the role to assign to the cluster upon creation.'
  end

  newproperty(:role_arn) do
    desc 'Read-only unique AWS resource name of the role for the service'
  end

  newproperty(:cluster) do
    desc 'The name of the cluster to assign the service to'
    isrequired
    defaultto "default"
  end
end

