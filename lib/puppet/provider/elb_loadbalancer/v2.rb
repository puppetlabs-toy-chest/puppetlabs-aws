require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:elb_loadbalancer).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    regions.collect do |region|
      begin
        load_balancers = []
        region_client = elb_client(region)
        region_client.describe_load_balancers.each do |response|
          response.data.load_balancer_descriptions.collect do |lb|
            load_balancers << new(load_balancer_to_hash(region, lb))
          end
        end
        load_balancers
      rescue Timeout::Error, StandardError => e
        raise PuppetX::Puppetlabs::FetchingAWSDataError.new(region, self.resource_type.name.to_s, e.message)
      end
    end.flatten
  end

  read_only(:region, :scheme, :listeners, :tags)

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]  # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov
      end
    end
  end

  def self.load_balancer_to_hash(region, load_balancer)
    instance_ids = load_balancer.instances.map(&:instance_id)
    instance_names = []
    unless instance_ids.empty?
      instances = ec2_client(region).describe_instances(instance_ids: instance_ids).collect do |response|
        response.data.reservations.collect do |reservation|
          reservation.instances.collect do |instance|
            instance
          end
        end.flatten
      end.flatten
      instances.each do |instance|
        name_tag = instance.tags.detect { |tag| tag.key == 'Name' }
        name = name_tag ? name_tag.value : nil
        instance_names << name if name
      end
    end
    listeners = load_balancer.listener_descriptions.collect do |listener|
      result = {
        'protocol' => listener.listener.protocol,
        'load_balancer_port' => listener.listener.load_balancer_port,
        'instance_protocol' => listener.listener.instance_protocol,
        'instance_port' => listener.listener.instance_port,
      }
      result['ssl_certificate_id'] = listener.listener.ssl_certificate_id unless listener.listener.ssl_certificate_id.nil?
      result
    end
    tag_response = elb_client(region).describe_tags(
      load_balancer_names: [load_balancer.load_balancer_name]
    )
    tags = {}
    unless tag_response.tag_descriptions.nil? || tag_response.tag_descriptions.empty?
      tag_response.tag_descriptions.first.tags.each do |tag|
        tags[tag.key] = tag.value unless tag.key == 'Name'
      end
    end
    subnet_names = []
    unless load_balancer.subnets.nil? || load_balancer.subnets.empty?
      response = ec2_client(region).describe_subnets(subnet_ids: load_balancer.subnets)
      subnet_names = response.data.subnets.collect do |subnet|
        subnet_name_tag = subnet.tags.detect { |tag| tag.key == 'Name' }
        subnet_name_tag ? subnet_name_tag.value : nil
      end.reject(&:nil?)
    end
    security_group_names = []
    unless load_balancer.security_groups.nil? || load_balancer.security_groups.empty?
      group_response = ec2_client(region).describe_security_groups(group_ids: load_balancer.security_groups)
      security_group_names = group_response.data.security_groups.collect(&:group_name)
    end
    {
      name: load_balancer.load_balancer_name,
      ensure: :present,
      region: region,
      availability_zones: load_balancer.availability_zones,
      instances: instance_names,
      listeners: listeners,
      tags: tags,
      subnets: subnet_names,
      security_groups: security_group_names,
      scheme: load_balancer.scheme,
    }
  end

  def exists?
    Puppet.info("Checking if load balancer #{name} exists in region #{target_region}")
    @property_hash[:ensure] == :present
  end

  # override default mk_resource_methods behaviour so this can be done in update
  def subnets=(value)
    Puppet.debug("Requesting subnets #{value.inspect} for ELB #{name} in region #{target_region}")
  end

  def availability_zones=(value)
    Puppet.debug("Requesting availability_zones #{value.inspect} for ELB #{name} in region #{target_region}")
  end

  def security_groups=(value)
    unless value.empty?
      ids = security_group_ids_from_names(value)
      elb_client(resource[:region]).apply_security_groups_to_load_balancer(
        load_balancer_name: name,
        security_groups: ids,
      ) unless ids.empty?
    end
  end

  def update
    Puppet.info("Updating load balancer #{name} in region #{target_region}")
    instances = resource[:instances]
    if ! instances.nil?
      instances = [instances] unless instances.is_a?(Array)
      self.class.add_instances_to_load_balancer(resource[:region], name, instances)
    end
    if !@property_hash[:subnets] || @property_hash[:subnets].empty? # EC2-classic
      fail_if_availability_zones_changed
    else
      if resource[:subnets].nil? || resource[:subnets].empty? # VPC using "default" subnets
        fail_if_availability_zones_changed
      elsif resource[:availability_zones].nil? || resource[:availability_zones].empty? # VPC, using specified subnets
        update_subnets(resource[:subnets])
      end
    end
  end

  def fail_if_availability_zones_changed
    if resource[:availability_zones].to_set != @property_hash[:availability_zones].to_set
      fail "availability_zones property is read-only once elb_loadbalancer is created."
    end
  end

  def update_subnets(value)
    if @property_hash[:subnets].empty? && !value.empty?
      fail 'Cannot set subnets on a EC2 instance'
    end

    to_create = value - @property_hash[:subnets]
    to_delete = @property_hash[:subnets] - value
    elb = elb_client(resource[:region])
    unless to_create.empty?
      create_ids = subnet_ids_from_names(to_create)
      elb.attach_load_balancer_to_subnets(
        load_balancer_name: name,
        subnets: create_ids,
      )
    end
    unless to_delete.empty?
      delete_ids = subnet_ids_from_names(to_delete)
      elb.detach_load_balancer_from_subnets(
        load_balancer_name: name,
        subnets: delete_ids,
      )
    end
  end

  def create
    Puppet.info("Creating load balancer #{name} in region #{target_region}")
    subnets = subnet_ids_from_names(resource[:subnets] || [])
    security_groups = security_group_ids_from_names(resource[:security_groups])
    zones = resource[:availability_zones] || []
    zones = [zones] unless zones.is_a?(Array)

    tags = resource[:tags] ? resource[:tags].map { |k,v| {key: k, value: v} } : []
    tags << {key: 'Name', value: name}

    listeners = resource[:listeners]
    listeners = [listeners] unless listeners.is_a?(Array)

    listeners_for_api = listeners.collect do |listener|
      result = {
        protocol: listener['protocol'],
        load_balancer_port: listener['load_balancer_port'],
        instance_protocol: listener['instanceprotocol'],
        instance_port: listener['instance_port'],
      }
      result[:ssl_certificate_id] = listener['ssl_certificate_id'] if listener.has_key?('ssl_certificate_id') and !listener['ssl_certificate_id'].nil?
      result
    end

    elb_client(target_region).create_load_balancer(
      load_balancer_name: name,
      listeners: listeners_for_api,
      availability_zones: zones,
      security_groups: security_groups,
      subnets: subnets,
      scheme: resource['scheme'],
      tags: tags_for_resource,
    )

    @property_hash[:ensure] = :present
    @property_hash[:availability_zones] = zones
    @property_hash[:subnets] = subnets

    instances = resource[:instances]
    if ! instances.nil?
      instances = [instances] unless instances.is_a?(Array)
      self.class.add_instances_to_load_balancer(resource[:region], name, instances)
    end
  end

  def self.add_instances_to_load_balancer(region, load_balancer_name, instance_names)
    response = ec2_client(region).describe_instances(
      filters: [
        {name: 'tag:Name', values: instance_names},
        {name: 'instance-state-name', values: ['pending', 'running']}
      ]
    )

    instance_ids = response.reservations.map(&:instances).
      flatten.map(&:instance_id)

    instance_input = instance_ids.collect do |id|
      { instance_id: id }
    end

    unless instance_input.empty?
      elb_client(region).register_instances_with_load_balancer(
        load_balancer_name: load_balancer_name,
        instances: instance_input
      )
    end
  end

  def security_group_ids_from_names(names)
    unless names.nil? || names.empty?
      vpc_id = if resource[:subnets]
        subnets = resource[:subnets]
        subnets = [subnets] unless subnets.is_a?(Array)
        vpc_id_from_subnet_name(subnets.first)
      else
        nil
      end

      filters = [{name: 'group-name', values: names}]
      filters << {name: 'vpc-id', values: [vpc_id]} if vpc_id

      names = [names] unless names.is_a?(Array)
      response = ec2_client(resource[:region]).describe_security_groups(filters: filters)
      response.data.security_groups.map(&:group_id)
    else
      []
    end
  end

  def vpc_id_from_subnet_name(name)
    response = ec2_client(resource[:region]).describe_subnets(filters: [
      {name: 'tag:Name', values: [name]}
    ])
    fail("No subnet with name #{name}") if response.data.subnets.empty?
    response.data.subnets.map(&:vpc_id).first
  end

  def subnet_ids_from_names(names)
    unless names.empty?
      names = [names] unless names.is_a?(Array)
      response = ec2_client(resource[:region]).describe_subnets(filters: [
        {name: 'tag:Name', values: names}
      ])
      response.data.subnets.map(&:subnet_id)
    else
      []
    end
  end

  def flush
    update unless @property_hash[:ensure] == :absent
  end

  def destroy
    Puppet.info("Destroying load balancer #{name} in region #{target_region}")
    elb_client(target_region).delete_load_balancer(
      load_balancer_name: name,
    )
    @property_hash[:ensure] = :absent
  end
end
