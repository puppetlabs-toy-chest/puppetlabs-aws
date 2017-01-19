require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:elb_loadbalancer).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances(ref_catalog=nil)
    Puppet.debug('Fetching ELB instances')
    regions.collect do |region|
        load_balancers = []
        elbs do |lb|
          retries = 0
          begin
            load_balancers << new(load_balancer_to_hash(region, lb, ref_catalog))
          rescue Aws::EC2::Errors::RequestLimitExceeded => e
            retries += 1
            if retries <= 8
              sleep_time = 2 ** retries
              Puppet.debug("Request limit exceeded, retry in #{sleep_time} seconds")
              sleep(sleep_time)
              retry
            else
              raise PuppetX::Puppetlabs::FetchingAWSDataError.new(region, self.resource_type.name.to_s, e.message)
            end
          rescue Timeout::Error, StandardError => e
            raise PuppetX::Puppetlabs::FetchingAWSDataError.new(region, self.resource_type.name.to_s, e.message)
          end
        end

      load_balancers
    end.flatten
  end

  def self.elbs
    # Make the calls to elb_client for each of the regions to fetch the ELB
    # resource information, yielding the individual ELB objects.
    regions.collect do |region|

      region_client = elb_client(region)
      Puppet.debug("Calling for ELB descriptions")
      response = region_client.describe_load_balancers()
      marker = response.next_marker

      response.load_balancer_descriptions.each do |lb|
        yield lb
      end

      while marker
        Puppet.debug("Calling for marked ELB description")
        response = region_client.describe_load_balancers({
          marker: marker
        })
        marker = response.next_marker
        response.load_balancer_descriptions.each do |lb|
          yield lb
        end
      end
    end
  end

  read_only(:region, :scheme, :tags, :dns_name)

  def self.prefetch(resources)
    ref_catalog = resources.values.first.respond_to?(:catalog) ? resources.values.first.catalog : nil

    instances(ref_catalog).each do |prov|
      if resource = resources[prov.name]  # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov
      end
    end
  end

  def self.load_balancer_to_hash(region, load_balancer, ref_catalog=nil)
    Puppet.debug("Generating load_balancer hash for #{load_balancer.load_balancer_name}")
    instance_ids = load_balancer.instances.map(&:instance_id)

    instance_names = []
    unless instance_ids.empty?
      instances_to_resolve = instance_ids.dup

      unless ref_catalog.nil?
        # If we have received a reference catalog, look for the resources that
        # have already been resolved to get hte data we require in the
        # conversion from ID to names.
        catalog_instances = ref_catalog.resources.select do |rec|
          rec.is_a? Puppet::Type::Ec2_instance and instance_ids.include? rec.provider.instance_id
        end

        catalog_instances.each do |rec|
          instance_names << rec.provider.name
          instances_to_resolve.delete(rec.provider.instance_id)
        end
      end

      if instances_to_resolve.size > 0
        # We arrive here when the instances that we are looking to convert from
        # ID to Name have not been found in the reference catalog.  As such,
        # here we need to make the call to ec2_client to resolve the instances
        # that are missing.
        Puppet.debug('Calling ec2_client for instances')
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
    end

    listeners = load_balancer.listener_descriptions.collect do |listener|
      result = {
        'protocol' => listener.listener.protocol,
        'load_balancer_port' => listener.listener.load_balancer_port,
        'instance_protocol' => listener.listener.instance_protocol,
        'instance_port' => listener.listener.instance_port,
      }
      result['ssl_certificate_id'] = listener.listener.ssl_certificate_id unless listener.listener.ssl_certificate_id.nil?
      result['policy_names'] = listener.policy_names unless listener.policy_names.nil? or listener.policy_names.size == 0
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
      subnets_to_resolve = load_balancer.subnets.dup

      unless ref_catalog.nil?
        # If we have received a reference catalog, look for the resources that
        # have already been resolved to get hte data we require in the
        # conversion from ID to names.
        catalog_subnets = ref_catalog.resources.select do |rec|
          rec.is_a? Puppet::Type::Ec2_vpc_subnet and load_balancer.subnets.include? rec.provider.id
        end

        catalog_subnets.each do |rec|
          subnet_names << rec.provider.name
          subnets_to_resolve.delete(rec.provider.id)
        end
      end

      if subnets_to_resolve.size > 0
        # We arrive here when the subnet that we are looking to convert from ID
        # to Name is not found in the catalog.  This requires us to make the
        # call to ec2_client to get the subnet information we need.
        Puppet.debug('Calling ec2_client for subnets')
        subnent_response = ec2_client(region).describe_subnets(subnet_ids: load_balancer.subnets)
        subnent_response.data.subnets.each do |subnet|
          subnet_name_tag = subnet.tags.detect { |tag| tag.key == 'Name' }
          if subnet_name_tag
            subnet_names << subnet_name_tag.value
          end
        end
      end
    end

    security_group_names = []
    unless load_balancer.security_groups.nil? || load_balancer.security_groups.empty?
      security_groups_to_resolve = load_balancer.security_groups.dup

      unless ref_catalog.nil?
        # If we have received a reference catalog, look for the resources that
        # have already been resolved to get hte data we require in the
        # conversion from ID to names.
        catalog_security_groups = ref_catalog.resources.select do |rec|
          rec.is_a? Puppet::Type::Ec2_securitygroup and load_balancer.security_groups.include? rec.provider.id
        end

        catalog_security_groups.each do |rec|
          security_group_names << rec.provider.name
          security_groups_to_resolve.delete(rec.provider.id)
        end
      end

      if security_groups_to_resolve.size > 0
        # We arrive here when the security groups that we are looking to
        # convert from IDs to names have not been found in the catalog, in
        # which case, we must make the call to AWS to get the security group
        # information we need to make the translation.
        Puppet.debug('Calling ec2_client for security_groups')
        group_response = ec2_client(region).describe_security_groups(group_ids: security_groups_to_resolve)
        group_response.data.security_groups.collect(&:group_name).each do |sg_name|
          security_group_names << sg_name
        end
      end
    end

    unless load_balancer.health_check.nil?
      health_check = {
        'target' => load_balancer.health_check.target,
        'interval' => load_balancer.health_check.interval,
        'timeout' => load_balancer.health_check.timeout,
        'unhealthy_threshold' => load_balancer.health_check.unhealthy_threshold,
        'healthy_threshold' => load_balancer.health_check.healthy_threshold,
      }
    end

    {
      name: load_balancer.load_balancer_name,
      ensure: :present,
      region: region,
      availability_zones: load_balancer.availability_zones,
      instances: instance_names,
      listeners: listeners,
      health_check: health_check,
      tags: tags,
      subnets: subnet_names,
      security_groups: security_group_names,
      scheme: load_balancer.scheme,
      dns_name: load_balancer.dns_name,
    }
  end

  def exists?
    Puppet.debug("Checking if load balancer #{name} exists in region #{target_region}")
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

  def health_check=(value)
    elb_client(resource[:region]).configure_health_check({
      load_balancer_name: name,
      health_check: value.inject({}){|keep,(k,v)| keep[k.to_sym] = v; keep},
    })
  end

  def listeners=(value)
    Puppet.debug("Requesting listeners #{value.inspect} for ELB #{name} in region #{target_region}")
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

    unless @property_hash[:listeners] == resource[:listeners]
      update_listeners
    end

  end

  def fail_if_availability_zones_changed
    if resource[:availability_zones].to_set != @property_hash[:availability_zones].to_set
      fail "availability_zones property is read-only once elb_loadbalancer is created."
    end
  end

  def update_listeners
    # Listeners are identified uniquely by their 'load_balancer_port' key.  As
    # such, we can collect a list of ports that should exist, and compare that
    # to the ones that already exist to make decisions about which to remove,
    # which to add, and which need modification.  The modification is a bit of
    # a misnomer, since it really ends up being a delete followed by an add.

    is_listener_ports = @property_hash[:listeners].collect {|x| x['load_balancer_port'].to_i }
    should_listener_ports = resource[:listeners].collect {|x| x['load_balancer_port'].to_i }

    # Collect a list of ports for listeners that should be deleted
    listeners_to_delete = is_listener_ports.collect {|listener_port|
      # Get the 'is' listener port and check if it 'should' exist
      listener_port unless should_listener_ports.include? listener_port
    }.compact

    # Collect a list of ports for listeners that should be created
    listeners_to_create = should_listener_ports.collect {|listener_port|
      # Get the 'should' listener port and check if already exists in 'is'
      listener_port unless is_listener_ports.include? listener_port
    }.compact

    resource[:listeners].each do |should_listener|
      # If our current should listeners is already known to need creating, then
      # we can safely skip comparison
      next if listeners_to_create.include? should_listener['load_balancer_port']

      # Identify and retrieve the existing listener to our current 'should'
      # listener by port
      is_listener = @property_hash[:listeners].select {|x|
        x['load_balancer_port'].to_i == should_listener['load_balancer_port'].to_i
      }.first

      # Unless we found a match, there is no comparison needed
      next unless is_listener

      # We arrive here if the load_balancer_ports match, but
      # @property_hash[:listeners] needs updating.  Thus we must compare what
      # is to what should be.

      # When comparing listeners, the following are possible keys to look at.
      # There is also a key for 'policy_names', but that is updated separated,
      # so when identifying equality of what is and what should be, the
      # following list of keys is sufficient.
      keys_to_compare = [ 'instance_port', 'instance_protocol',
                          'load_balancer_port', 'protocol',
                          'ssl_certificate_id' ]

      # Build the hashes to compare from what is and what should be, using the
      # above keys.
      should_hash = {}
      is_hash = {}
      keys_to_compare.each do |k|
        if should_listener[k]
          should_hash[k] = should_listener[k]
        end

        if is_listener[k]
          is_hash[k] = is_listener[k]
        end
      end

      # Perform the comparison after normalizing the values from each.
      if self.class.normalize_values(is_hash) != self.class.normalize_values(should_hash)
        # This queues up the modify by adding the load_balancer_port to both
        # the add and delete arrays.

        # Add the port for deletion if its not already there
        unless listeners_to_delete.include? is_listener['load_balancer_port'].to_i
          listeners_to_delete << is_listener['load_balancer_port'].to_i
        end

        # Add the port for creation if its not already there
        unless listeners_to_create.include? should_listener['load_balancer_port'].to_i
          listeners_to_create << should_listener['load_balancer_port'].to_i
        end
      end
    end

    # Perform the delete for listeners that need not exist
    if listeners_to_delete.size > 0
      Puppet.debug("deleting listeners #{listeners_to_delete} on ELB #{resource[:name]}")
      elb_client.delete_load_balancer_listeners({
        load_balancer_name: resource[:name],
        load_balancer_ports: listeners_to_delete,
      })
    end

    # Perform the create for listeners that should exist but don't
    if listeners_to_create.size > 0
      listeners = resource[:listeners].collect {|listener|
        if listeners_to_create.include? listener['load_balancer_port'].to_i
          hsh = {
            protocol: listener['protocol'],
            load_balancer_port: listener['load_balancer_port'],
            instance_protocol: listener['instance_protocol'],
            instance_port: listener['instance_port'],
          }
          if listener['ssl_certificate_id']
            hsh['ssl_certificate_id'] = listener['ssl_certificate_id']
          end

          hsh
        end
      }.compact

      Puppet.debug("Creating listeners #{listeners} on ELB #{resource[:name]}")
      elb_client.create_load_balancer_listeners({
        load_balancer_name: resource[:name],
        listeners: listeners
      })
    end

    resource[:listeners].each do |should_listener|
      # If the resource does not specify a policy_name, do nothing
      next unless should_listener['policy_names']

      # Match the should_listener to the is_listener
      is_listener = @property_hash[:listeners].select {|x|
        x['load_balancer_port'].to_i == should_listener['load_balancer_port'].to_i
      }.first

      # Update the working listener policy if requested
      if should_listener['policy_names'] and should_listener['policy_names'] != is_listener['policy_names']
        Puppet.debug("Calling elb_client for policy_names update on #{resource[:name]}")
        elb_client.set_load_balancer_policies_of_listener({
          load_balancer_name: resource[:name],
          load_balancer_port: should_listener['load_balancer_port'],
          policy_names: should_listener['policy_names'],
        })
      end
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

    instances = resource[:instances]
    if ! instances.nil?
      instances = [instances] unless instances.is_a?(Array)
      self.class.add_instances_to_load_balancer(resource[:region], name, instances)
    end

    @property_hash[:ensure] = :present
    @property_hash[:availability_zones] = zones
    @property_hash[:subnets] = subnets
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
