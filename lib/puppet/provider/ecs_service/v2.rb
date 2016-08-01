require_relative '../../../puppet_x/puppetlabs/aws.rb'


Puppet::Type.type(:ecs_service).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def initialize(value={})
    super(value)
    @property_flush = {}
  end

  def self.instances
    results = ecs_client.list_clusters().cluster_arns.collect do |cluster_arn|
      cluster_name = cluster_arn.match(/^(.*)\/([_\w\d-]+)$/)[2]
      Puppet.debug("Working on #{cluster_name}")

      ecs_service_list = ecs_client.list_services({cluster: cluster_arn})
      service_arns = ecs_service_list.service_arns

      unless service_arns.size > 0
        Puppet.debug("Skipping #{cluster_arn} due to empty service list")
        next
      end

      response = ecs_client.describe_services({
        cluster: cluster_arn,
        services: service_arns
      })

      ecs_service_descriptions = response.services.map {|s| s}

      # Results from #list_services are paginated, so if next_token is present,
      # then we need to make another call to list passing in the token we've
      # received from the last call.  Appends discovered service descriptions
      # to the ecs_service_descriptions array for looping over the complete set
      # of discoverd service descriptions below to generate the instances.
      token = ecs_service_list.next_token
      while token
        Puppet.debug('Next token found, proceeding with discovery')
        results = ecs_client.list_services({
          cluster: cluster_arn,
          next_token: token
        })
        token = results.next_token
        service_arns = results.service_arns

        response = ecs_client.describe_services({
          cluster: cluster_arn,
          services: service_arns,
        })
        response.services.each {|s| ecs_service_descriptions << s}
      end

      ecs_service_descriptions.collect do |service|

        task_family = service.task_definition.match(/^(.*)\/([_\w\d-]+):(\d+)$/)[2]

        ecs_service = {
          name: service.service_name,
          ensure: :present,
          status: service.status,
          arn: service.service_arn,
          load_balancers: deserialize_load_balancers(service.load_balancers),
          desired_count: service.desired_count,
          running_count: service.running_count,
          pending_count: service.pending_count,
          task_definition: task_family,
          deployment_configuration: deserialize_deployment_configuration(service.deployment_configuration),
          cluster: cluster_name,
        }

        unless service.role_arn.is_a? NilClass
          ecs_service[:role] = service.role_arn.match(/^(.*)\/([_\w\d-]+)$/)[2]
          ecs_service[:role_arn] =  service.role_arn
        end

        new(ecs_service)

      end
    end

    results.flatten.select {|i| i }
  end

  read_only(:load_balancers, :role_arn, :role)

  def self.prefetch(resources)
    instances.each do |prov|
      # Skipped instances return a nil object, check here for sanity
      next if prov.is_a? NilClass
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end

  def self.deserialize_load_balancers(load_balancers)
    load_balancers.collect do |lb|
      normalize_values({
        load_balancer_name: lb.load_balancer_name,
        container_name: lb.container_name,
        container_port: lb.container_port
      })
    end
  end

  def self.deserialize_deployment_configuration(deployment_configuration)
    normalize_hash({
      maximum_percent: deployment_configuration.maximum_percent,
      minimum_healthy_percent: deployment_configuration.minimum_healthy_percent,
    })
  end

  def deployment_configuration=(value)
    @property_flush[:deployment_configuration] = value
  end

  def desired_count=(value)
    @property_flush[:desired_count] = value
  end

  def task_definition=(value)
    @property_flush[:task_definition] = value
  end

  def exists?
    Puppet.debug("Checking if ECS service #{name} exists")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.debug("Creating ecs_service #{resource[:name]}")

    ecs_service = {
      service_name: resource[:name],
      desired_count: resource[:desired_count],
      task_definition: resource[:task_definition],
      cluster: resource[:cluster],
    }

    if resource[:load_balancers]
      ecs_service[:load_balancers] = resource[:load_balancers]
    end

    if resource[:role]
      ecs_service[:role] = resource[:role]
    end

    if resource[:deployment_configuration]
      ecs_service[:deployment_configuration] = resource[:deployment_configuration]
    end

    ecs_client.create_service(ecs_service)
    @property_hash[:ensure] = :present
  end

  def destroy
    Puppet.debug("Destroying ecs_service #{@property_hash[:name]}")

    ecs_client.delete_service({
      service: @property_hash[:name],
      cluster: @property_hash[:cluster]
    })
    @property_hash[:ensure] = :absent
  end

  def flush
    if @property_hash[:ensure] != :absent
      Puppet.debug("Flushing ECS service for #{@property_hash[:name]}")

      if @property_flush.keys.size > 0
        service_def = {
          service: @property_hash[:name],
          cluster: @property_hash[:cluster],
        }

        unless @property_flush[:deployment_configuration].nil?
          service_def[:deployment_configuration] = @property_flush[:deployment_configuration]
        end

        unless @property_flush[:desired_count].nil?
          service_def[:desired_count] = @property_flush[:desired_count]
        end

        unless @property_flush[:task_definition].nil?
          service_def[:task_definition] = @property_flush[:task_definition]
        end

        ecs_client.update_service(service_def)
      end
    end
  end

end
