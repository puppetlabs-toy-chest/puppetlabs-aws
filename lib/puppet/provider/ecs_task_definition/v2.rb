require_relative '../../../puppet_x/puppetlabs/aws.rb'


Puppet::Type.type(:ecs_task_definition).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def initialize(value={})
    super(value)
    @property_flush = {}
  end

  def self.instances

    task_families = ecs_client.list_task_definition_families({status: 'ACTIVE'}).families

    results = task_families.collect do |task_family|

      begin
        task = ecs_client.describe_task_definition({task_definition: task_family}).task_definition
      rescue
        Puppet.err("Skipping #{task_family} due to failed call to #describe_task_definition()")
        next
      end

      container_defs = deserialize_container_definitions(task.container_definitions)

      new({
        name: task.family,
        ensure: :present,
        arn: task.task_definition_arn,
        revision: task.revision,
        volumes: task.volumes,
        container_definitions: container_defs,
      })
    end
    results.flatten.select {|i| i }
  end

  def self.prefetch(resources)
    instances.each do |prov|
      # Skipped instances return a nil object, check here for sanity
      next if prov.is_a? NilClass
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end

  def self.deserialize_container_definitions(container_definitions)
    # Convert the container_definition objects into data structures that we can
    # work with.
    #
    # Empty arrays returned by the API confuse what the user has specified.  In
    # the case where a container option has not been set by the user, but the
    # API returns an empty Array for that option's value, comparison becomes
    # difficult.  Dropping the empty array from the container_definition data
    # strcucture here ensures that we are able to do the proper comparison.
    # This results in a match when empty arrays are present, though the user
    # has not specified the option.  Also here, if a delta is detected, the API
    # does not require that those empty objects be set, and thus the result is
    # the same as if we  had supplied the empty array on the way back out.  In
    # either case, its simpler to leave the empty arrays out of the
    # conversation between what the resource has set and what the API result
    # is.
    #
    # If an environment is detected, convert it to a simpler key-value hash
    # that we can work with.
    #
    defs = container_definitions.collect {|cd|
      cd.to_h.reject {|k,v| v.is_a? Array and v.size == 0 }
    }

    data = normalize_values(defs)

    data.collect {|cd|
      unless cd['environment'].nil?
        cd['environment'] = deserialize_environment(cd['environment'])
      end
      cd
    }
  end

  def self.serialize_container_definitions(container_definitions)
    # Prepare a container_definition data strucuture for loading to AWS.
    #
    # If an environment is found on a given container, replace it with an AWS
    # native data strucuture as described in the serialize_environment()
    # method.
    #
    container_definitions.collect {|cd|
      unless cd['environment'].nil?
        cd['environment'] = serialize_environment(cd['environment'])
      end
      cd
    }
  end

  def exists?
    Puppet.debug("Checking if ECS task definition #{name} exists")
    @property_hash[:ensure] == :present
  end

  def create
    ecs_client.register_task_definition({
      family: resource[:name],
      container_definitions: self.class.serialize_container_definitions(resource[:container_definitions]),
    })
    @property_hash[:ensure] = :present
  end

  def destroy
    ecs_client.deregister_task_definition({
      task_definition: @property_hash[:arn],
    })
    @property_hash[:ensure] = :absent
  end

  def container_definitions=(value)
    @property_flush[:container_definitions] = value
  end

  def flush
    Puppet.debug("Flushing ECS task definition for #{@property_hash[:name]}")

    containers = []
    if @property_hash[:container_definitions] and @property_flush[:container_definitions]
      Puppet.debug("Comparing container definitions for #{@property_hash[:name]}")
      is_containers = self.class.normalize_values(@property_hash[:container_definitions])
      should_containers = self.class.normalize_values(@property_flush[:container_definitions])

      if is_containers != should_containers
        containers = rectify_container_delta(is_containers, should_containers)
      else
        Puppet.debug('Containers are equivlient')
      end
    end

    if containers.size > 0
      Puppet.debug("Registering new task definition for #{@property_hash[:name]}")

      ecs_client.register_task_definition({
        family: @property_hash[:name],
        container_definitions: self.class.serialize_container_definitions(containers),
      })
    else
      Puppet.debug("No container modifications needed on ECS task #{@property_hash[:name]}")
    end
  end

  def rectify_container_delta(is_containers, should_containers)
    # Compares two container_definition data strucutures.
    #
    # The assumption here is that each container will be uniquly named.  Though
    # I cannot find documentation in AWS to reflect this, it seems like a
    # reasonable assumption to make, without which would make detection of an
    # existing container somewhat more problematic.
    #
    # Compares the @property_flush container set by the resource property's
    # container_definition=() call to that which was discovered by
    # self.instances and stored in @property_hash.
    #
    # Conainers are first normalized to a common format.
    #
    # Containers with duplicate names are not handled.
    #
    # Returns an array of container hashes that can be sent to the ecs_client's
    # register_task_definition() method.
    #

    is = self.class.normalize_values(is_containers)
    should = self.class.normalize_values(should_containers)

    if is != should

      containers = []
      should.each do |should_container|
        Puppet.debug("Inspecting container #{should_container}")

        # Check if the current 'should' container is already correct
        if is.include? should_container
          Puppet.debug('Current container is correct')
          containers << should_container
          next
        else
          Puppet.debug('Container should be present, but was not found')
          matches = is.select {|c|
            c['name'] == should_container['name']
          }

          if matches.size == 1
            matched_container = matches.first
            Puppet.debug("Matched existing container name, inspecting")

            if self.resource[:replace_image] == :false
              Puppet.debug('Copying image from matched existing container as requested')
              should_container['image'] = matched_container['image']
            end

            merged_container = matched_container.merge(should_container)
            containers << merged_container
          elsif matches.size > 1
            Puppet.error("Multiple containers with matching names discovered, not handling")
            next
          else
            Puppet.debug("Requested container matches no existing named container, adding")
            containers << should_container
            next
          end

        end
      end

      Puppet.debug('Returning merged container results')
      return self.class.normalize_values(containers)
    else
      Puppet.debug('Compared container_definitions already match')
      return is
    end
  end

  def self.deserialize_environment(array)
    # Convert a container environment from AWS-native to a simple key-value
    # hash.
    #
    #   [{'name' => k, 'value' => v}] becomes {k => v}
    #
    data = {}
    array.each {|i|
      data[i['name']] = i['value'].to_s
    }
    data
  end

  def self.serialize_environment(hash)
    # Convert a container environment data from simple key value paris into
    # AWS-native format.
    #
    #   {k => v} becomes [{'name' => k, 'value' => v}]
    #
    data = []
    hash.each {|k,v|
      data << {'name' => k, 'value' => v.to_s}
    }
    data
  end

end

