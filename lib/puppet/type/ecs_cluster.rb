Puppet::Type.newtype(:ecs_cluster) do
  @doc = 'Type representing ECS clusters.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the cluster to manage.'
    validate do |value|
      fail Puppet::Error, 'Empty ECS cluster names are not allowed' if value == ''
    end
  end

  newproperty(:arn) do
    desc 'Read-only unique AWS resource name assigned to the cluster'
  end

  newproperty(:status) do
    desc 'Read-only status of the ECS cluster'
  end

  newproperty(:registered_container_instances_count) do
    desc 'Read-only count of the registerd containers for the cluster'
  end

  newproperty(:running_tasks_count) do
    desc 'Read-only count of the running ECS tasks on the cluster'
  end

  newproperty(:pending_tasks_count) do
    desc 'Read-only count of the tasks in a pending state on the cluster'
  end

  newproperty(:active_services_count) do
    desc 'Read-only count of the number of services in an active state'
  end
end

