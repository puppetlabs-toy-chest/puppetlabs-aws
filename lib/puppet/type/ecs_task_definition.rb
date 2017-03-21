Puppet::Type.newtype(:ecs_task_definition) do
  @doc = 'Type representing ECS clusters.'

  autorequire(:iam_role) do
    self[:role]
  end

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the task to manage.'
    validate do |value|
      fail Puppet::Error, 'Empty ECS task names are not allowed' if value == ''
    end
  end

  newparam(:replace_image) do
    desc 'Take the image into consideration when comparing the containers'
    newvalues(:true, :false)
    defaultto :true
  end

  newproperty(:arn) do
    desc 'Read-only unique AWS resource name assigned to the ECS service'
  end

  newproperty(:revision) do
    desc 'Read-only revision number of the task definition'
  end

  newproperty(:volumes, :array_matching => :all) do
    desc 'An array of hashes to handle for the task'

    def insync?(is)
      one = provider.class.normalize_values(is)
      two = provider.class.normalize_values(should)
      one == two
    end
  end

  newproperty(:container_definitions, :array_matching => :all) do
    desc 'An array of hashes representing the container definition'
    isrequired
    def insync?(is)
      # Compare the merged result of the container_definitions with what *is* currently.
      one = provider.rectify_container_delta(is, should)
      two = provider.class.normalize_values(is)
      one == two
    end
  end

  newproperty(:role) do
    desc 'The short name or full ARN of the IAM role that containers in this task can assume.'
  end
end

