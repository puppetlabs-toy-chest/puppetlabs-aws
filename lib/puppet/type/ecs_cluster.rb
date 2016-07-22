Puppet::Type.newtype(:ecs_cluster) do
  @doc = 'Type representing ECS clusters.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the cluster to manage.'
    validate do |value|
      fail Puppet::Error, 'Empty ECS cluster names are not allowed' if value == ''
    end
  end

  newproperty(:arn)
  newproperty(:status)
  newproperty(:registered_container_instances_count)
  newproperty(:running_tasks_count)
  newproperty(:pending_tasks_count)
  newproperty(:active_services_count)
end

