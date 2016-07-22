Puppet::Type.newtype(:ecs_task_definition) do
  @doc = 'Type representing ECS clusters.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the task to manage.'
    validate do |value|
      fail Puppet::Error, 'Empty ECS task names are not allowed' if value == ''
    end
  end

  newproperty(:arn)
  newproperty(:revision)
  newproperty(:requires_attributes)
  newproperty(:volumes)
  newproperty( :container_definitions, :array_matching => :all) do
    isrequired
    def insync?(is)
      provider.class.normalize_values(@should) == provider.class.normalize_values(is)
    end
  end
end

