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
      # Compare the merged result of the container_definitions with what *is* currently.
      one = provider.class.rectify_container_delta(is, should)
      two = provider.class.normalize_values(is)
      one == two
    end
  end
end

