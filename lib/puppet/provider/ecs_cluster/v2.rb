require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:ecs_cluster).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    arn_list = ecs_client.list_clusters().cluster_arns
    response = ecs_client.describe_clusters({clusters: arn_list})
    results = response.clusters.collect do |cluster|
      new({
        name: cluster.cluster_name,
        ensure: :present,
        arn: cluster.cluster_arn,
        status: cluster.status,
        registered_container_instances_count: cluster.registered_container_instances_count,
        running_tasks_count: cluster.running_tasks_count,
        pending_tasks_count: cluster.pending_tasks_count,
        active_services_count: cluster.active_services_count,
      })
    end
    results.flatten.select {|i| i }
  end

  read_only(:arn, :status, :pending_tasks_count, :running_tasks_count,
            :active_services_count, :registered_container_instances_count)

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end

  def exists?
    Puppet.debug("Checking if ECS cluster #{name} exists")
    @property_hash[:ensure] == :present
  end

  def create
    ecs_client.create_cluster({
      cluster_name: resource[:name]
    })
    @property_hash[:ensure] = :present
  end

  def destroy
    ecs_client.delete_cluster({
      cluster: resource[:name]
    })
    @property_hash[:ensure] = :absent
  end

end

