require_relative '../../../puppet_x/puppetlabs/aws.rb'
require 'base64'

Puppet::Type.type(:ec2_instance).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws
  confine feature: :retries

  mk_resource_methods
  remove_method :tags=

  def initialize(value={})
    super(value)
    @property_flush = {}
  end

  def self.instances
    regions.collect do |region|
      begin
        instances = []
        subnets = Hash.new()

        subnets_response = ec2_client(region).describe_subnets()
        subnets_response.data.subnets.each do |subnet|
          subnet_name = extract_name_from_tag(subnet)
          subnets[subnet.subnet_id] = subnet_name if subnet_name
        end

        ec2_client(region).describe_instances(filters: [
          {name: 'instance-state-name', values: ['pending', 'running', 'stopping', 'stopped']}
        ]).each do |response|
          response.data.reservations.each do |reservation|
            reservation.instances.each do |instance|
              hash = instance_to_hash(region, instance, subnets)
              instances << new(hash) if has_name?(hash)
            end
          end
        end
        instances
      rescue Timeout::Error, StandardError => e
        raise PuppetX::Puppetlabs::FetchingAWSDataError.new(region, self.resource_type.name.to_s, e.message)
      end
    end.flatten
  end

  read_only(:instance_id, :instance_type, :image_id, :region, :user_data,
            :key_name, :availability_zones, :monitoring, :interfaces,
            :subnet, :ebs_optimized, :block_devices, :private_ip_address,
            :iam_instance_profile_arn, :iam_instance_profile_name)

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region
      end
    end
  end

  def self.instance_to_hash(region, instance, subnets)
    ec2 = ec2_client(region)
    name = name_from_tag(instance)
    return {} unless name
    tags = {}
    subnet_name = nil
    monitoring = instance.monitoring.state == "enabled" ? true : false
    instance.tags.each do |tag|
      tags[tag.key] = tag.value unless tag.key == 'Name'
    end
    if instance.subnet_id
      subnet_name = subnets[instance.subnet_id] ? subnets[instance.subnet_id] : nil
    end

    devices = instance.block_device_mappings.collect do |mapping|
      {
        device_name: mapping.device_name,
        delete_on_termination: mapping.ebs.delete_on_termination,
      }
    end


    # We capture the instance data about its interfaces to support lookup later
    # in flush so we know which interface ID to modify the security groups on.
    interface_hash = {}
    instance.network_interfaces.each do |interface|
      interface_hash[interface.network_interface_id] = {
        security_groups: interface.groups.collect do |group|
          {
            group_name: group.group_name,
            group_id: group.group_id,
          }
        end
      }
    end

    # Find the setting for termination protection
    term_att = ec2.describe_instance_attribute({ attribute: 'disableApiTermination', instance_id: instance.image_id})

    config = {
      name: name,
      instance_type: instance.instance_type,
      image_id: instance.image_id,
      instance_id: instance.instance_id,
      id: instance.instance_id,
      monitoring: monitoring,
      key_name: instance.key_name,
      availability_zone: instance.placement.availability_zone,
      ensure: instance.state.name.to_sym,
      tags: tags,
      region: region,
      tenancy: instance.placement.tenancy,
      hypervisor: instance.hypervisor,
      termination_protection: term_att,
      iam_instance_profile_arn: instance.iam_instance_profile ? instance.iam_instance_profile.arn : nil,
      virtualization_type: instance.virtualization_type,
      security_groups: instance.security_groups.collect(&:group_name),
      subnet: subnet_name,
      ebs_optimized: instance.ebs_optimized,
      kernel_id: instance.kernel_id,
      interfaces: interface_hash,
    }

    if instance.state.name == 'running'
      config[:public_dns_name] = instance.public_dns_name
      config[:private_dns_name] = instance.private_dns_name
      config[:public_ip_address] = instance.public_ip_address
      config[:private_ip_address] = instance.private_ip_address
    end
    config[:block_devices] = devices unless devices.empty?
    config
  end

  def exists?
    Puppet.debug("Checking if instance #{name} exists in region #{target_region}")
    running? || stopped?
  end

  def running?
    Puppet.debug("Checking if instance #{name} is running in region #{target_region}")
    [:present, :pending, :running].include? @property_hash[:ensure]
  end

  def stopped?
    Puppet.debug("Checking if instance #{name} is stopped in region #{target_region}")
    [:stopping, :stopped].include? @property_hash[:ensure]
  end

  def using_vpc?
    resource[:subnet] || vpc_only_account?
  end

  def determine_subnet(vpc_ids)
    ec2 = ec2_client(resource[:region])

    # filter by VPC, since describe_subnets doesn't work on empty tag:Name
    subnet_response = ec2.describe_subnets(filters: [
      {name: "vpc-id", values: vpc_ids}])

    subnet_name = if (resource[:subnet].nil? || resource[:subnet].empty?) && vpc_only_account?
                    'default'
                  else
                    resource[:subnet]
                  end

    # then find the name in the VPC subnets that we have
    subnets = subnet_response.data.subnets.select do |s|
      if subnet_name.nil? || subnet_name.empty?
        puts ! s.tags.any? { |t| t.key == 'Name' }
        ! s.tags.any? { |t| t.key == 'Name' }
      else
        s.tags.any? { |t| t.key == 'Name' && t.value == subnet_name }
      end
    end

    # Handle ambiguous name collisions by selecting first matching subnet / vpc.
    # This needs to be a stable sort to be idempotent and it needs to prefer the "a"
    # availability_zone as others might be less feature complete. Users always
    # have the option of overriding the subnet if that choice is not proper.
    subnet = subnets.sort { |a,b| [ a.availability_zone, a.subnet_id ] <=> [ b.availability_zone, b.subnet_id ] }.first
    if subnets.length > 1
      subnet_map = subnets.map { |s| "#{s.subnet_id} (vpc: #{s.vpc_id})" }.join(', ')
      Puppet.warning "Ambiguous subnet name '#{subnet_name}' resolves to subnets #{subnet_map} - using #{subnet.subnet_id}"
    end

    subnet
  end

  def config_with_network_details(config)
    groups = resource[:security_groups]
    groups = [groups] unless groups.is_a?(Array)
    groups = groups.reject(&:nil?)

    # this replicates the default behaviour of the API but also allows
    # us to query the group id which varies between VPC or standard accounts
    groups = ['default'] if groups.empty?

    classic_groups = []
    vpc_groups = Hash.new

    ec2 = ec2_client(resource[:region])
    ec2.describe_security_groups(filters: [
      {name: 'group-name', values: groups},
    ]).each do |response|
      response.security_groups.each do |sg|
        classic_groups.push(sg) if sg.vpc_id.nil?
        (vpc_groups[sg.vpc_id] ||= []).push(sg) if sg.vpc_id
      end
    end

    matching_groups = unless using_vpc?
      classic_groups
    else
      if vpc_groups.empty?
        raise Puppet::Error,
          "When specifying a subnet you must specify a security group associated with a VPC"
      end
      subnet = determine_subnet(vpc_groups.keys)
      if subnet.nil?
        raise Puppet::Error,
          "Security groups '#{groups.join(', ')}' not found in VPCs '#{vpc_groups.keys.join(', ')}'"
      end
      config[:subnet_id] = subnet.subnet_id
      vpc_groups[subnet.vpc_id]
    end

    group_ids = matching_groups.map(&:group_id)

    # All instances have to be in a security group, and if one is not specified
    # EC2 will use the default. The reverse of this is if you only specify the default group
    # we're fine to rely on the default EC2 behaviour
    unless groups == ['default'] && group_ids.empty?
      if (groups.uniq.length != matching_groups.map(&:group_name).uniq.length)
        Puppet.warning <<-EOF
Mismatch between specified and found security groups.
Specified #{groups.length}: #{groups.join(', ')}
Found #{matching_groups.length}:
#{matching_groups.map { |g| 'Name : ' + g.group_name + ' - ' + g.group_id + "\n" }}
        EOF
      end
    end

    config[:security_group_ids] = group_ids.empty? ? nil : group_ids
    config
  end

  def config_with_devices(config)
    devices = resource[:block_devices]
    devices = [devices] unless devices.is_a?(Array)
    devices = devices.reject(&:nil?)
    mappings = devices.collect do |device|
      {
        device_name: device['device_name'],
        ebs: {
          volume_size: device['volume_size'],
          snapshot_id: device['snapshot_id'],
          delete_on_termination: device['delete_on_termination'] || true,
          volume_type: device['volume_type'] || 'gp2',
          iops: device['iops'],
          encrypted: device['encrypted'] ? true : nil
        },
      }
    end
    config['block_device_mappings'] = mappings unless mappings.empty?
    config
  end

  def config_with_key_details(config)
    key = resource[:key_name] ? resource[:key_name] : false
    config['key_name'] = key if key
    config
  end

  def config_with_ip(config)
    if resource[:associate_public_ip_address] == :true
      config[:network_interfaces] = [{
        device_index: 0,
        subnet_id: config[:subnet_id],
        groups: config[:security_group_ids],
        associate_public_ip_address: true,
      }]
      # If both public and private ip specified, then the private_ip_address must be within the network_interfaces structure
      #  Module currently only supports a single network interface, therefore attatch any specified private ip address
      #  to the first network interface.
      if resource['private_ip_address'] && resource['private_ip_address'] != "auto" && using_vpc?
        config[:network_interfaces].first[:private_ip_address] = resource['private_ip_address']
      end
      config[:subnet_id] = nil
      config[:security_group_ids] = nil
    elsif resource['private_ip_address'] && resource['private_ip_address'] != "auto" && using_vpc?
      config['private_ip_address'] = resource['private_ip_address']
    end

    config
  end

  def create
    if stopped?
      restart
    else
      Puppet.info("Starting instance #{name} in region #{resource[:region]}")
      data = resource[:user_data].nil? ? nil : Base64.encode64(resource[:user_data])

      ec2 = ec2_client(resource[:region])

      config = {
        image_id: resource[:image_id],
        min_count: 1,
        max_count: 1,
        instance_type: resource[:instance_type],
        user_data: data,
        ebs_optimized: resource[:ebs_optimized].to_s,
        disable_api_termination: resource[:termination_protection],
        instance_initiated_shutdown_behavior: resource[:instance_initiated_shutdown_behavior].to_s,
        iam_instance_profile: resource[:iam_instance_profile_arn] ?
          Hash['arn' => resource[:iam_instance_profile_arn]] :
          Hash['name' => resource[:iam_instance_profile_name]],
        placement: {
          availability_zone: resource[:availability_zone],
          tenancy: resource[:tenancy],
        },
        monitoring: {
          enabled: resource[:monitoring].to_s,
        }
      }

      config = config_with_key_details(config)
      config = config_with_devices(config)
      config = config_with_network_details(config)
      config = config_with_ip(config)

      response = ec2.run_instances(config)

      instance_ids = response.instances.map(&:instance_id)

      with_retries(:max_tries => 5) do
        ec2.create_tags(
          resources: instance_ids,
          tags: extract_resource_name_from_tag
        )
      end

      @property_hash[:instance_id] = instance_ids.first
      @property_hash[:ensure] = :present
    end
  end

  def restart
    Puppet.info("Restarting instance #{name} in region #{resource[:region]}")
    ec2 = ec2_client(resource[:region])
    ec2.start_instances(instance_ids: [instance_id])
    @property_hash[:ensure] = :present
  end

  def stop
    create unless exists?
    Puppet.info("Stopping instance #{name} in region #{target_region}")
    ec2 = ec2_client(target_region)
    # Can't stop an instance that hasn't started yet
    ec2.wait_until(:instance_running, instance_ids: [@property_hash[:instance_id]])
    ec2.stop_instances(
      instance_ids: [@property_hash[:instance_id]]
    )
    @property_hash[:ensure] = :stopped
  end

  def security_groups=(value)
    @property_flush[:security_groups] = value
  end

  def destroy
    Puppet.info("Deleting instance #{name} in region #{target_region}")
    ec2 = ec2_client(target_region)
    ec2.terminate_instances(instance_ids: [instance_id])
    ec2.wait_until(:instance_terminated, instance_ids: [instance_id])
    @property_hash[:ensure] = :absent
  end

  def flush
    if @property_hash[:ensure] != :absent
      Puppet.debug("Flushing EC2 instance #{@property_hash[:name]}")
      ec2 = ec2_client(resource[:region])

      # Check if we need to modify the security groups for an interface
      if @property_flush.keys.include? :security_groups
        if @property_hash[:interfaces].size != 1
          Puppet.warning('Handling security group changes on instances with
                         multiple interfaces is not implemented')
        else
          interface_id = @property_hash[:interfaces].keys[0]
          group_ids = ec2.describe_security_groups({
            filters: [
              {name: 'group-name', values: @property_flush[:security_groups]},
            ]
          }).security_groups.map(&:group_id)

          Puppet.debug("Calling for security group modification #{group_ids}")
          ec2.modify_network_interface_attribute({
            groups: group_ids,
            network_interface_id: interface_id
          })
        end

      end
    end
  end
end
