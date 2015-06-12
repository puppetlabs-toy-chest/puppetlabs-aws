require_relative '../../../puppet_x/puppetlabs/aws.rb'
require 'base64'

Puppet::Type.type(:ec2_instance).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws
  confine feature: :retries

  mk_resource_methods
  remove_method :tags=

  def self.instances
    regions.collect do |region|
      begin
        instances = []
        subnets = Hash.new()

        subnets_response = ec2_client(region).describe_subnets()
        subnets_response.data.subnets.each do |subnet|
          subnet_name = name_from_tag(subnet)
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
      rescue StandardError => e
        raise PuppetX::Puppetlabs::FetchingAWSDataError.new(region, self.resource_type.name.to_s, e.message)
      end
    end.flatten
  end

  read_only(:instance_id, :instance_type, :region, :user_data, :key_name,
            :availability_zones, :security_groups, :monitoring, :subnet,
            :ebs_optimized, :block_devices, :private_ip_address,
            :iam_instance_profile_arn, :iam_instance_profile_name)

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region
      end
    end
  end

  def self.instance_to_hash(region, instance, subnets)
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
        volume_id: mapping.ebs.volume_id,
      }
    end

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
      hypervisor: instance.hypervisor,
      iam_instance_profile_arn: instance.iam_instance_profile ? instance.iam_instance_profile.arn : nil,
      virtualization_type: instance.virtualization_type,
      security_groups: instance.security_groups.collect(&:group_name),
      subnet: subnet_name,
      ebs_optimized: instance.ebs_optimized,
      kernel_id: instance.kernel_id,
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
    Puppet.info("Checking if instance #{name} exists in region #{target_region}")
    running? || stopped?
  end

  def running?
    Puppet.info("Checking if instance #{name} is running in region #{target_region}")
    [:present, :pending, :running].include? @property_hash[:ensure]
  end

  def stopped?
    Puppet.info("Checking if instance #{name} is stopped in region #{target_region}")
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

    # then find the name in the VPC subnets that we have
    subnets = subnet_response.data.subnets.select do |s|
      if resource[:subnet].nil? || resource[:subnet].empty?
        ! s.tags.any? { |t| t.key == 'Name' }
      else
        s.tags.any? { |t| t.key == 'Name' && t.value == resource[:subnet] }
      end
    end

    # handle ambiguous name collisions by selecting first matching subnet / vpc
    subnet = subnets.first
    if subnets.length > 1
      subnet_map = subnets.map { |s| "#{s.subnet_id} (vpc: #{s.vpc_id})" }.join(', ')
      Puppet.warning "Ambiguous subnet name '#{resource[:subnet]}' resolves to subnets #{subnet_map} - using #{subnet.subnet_id}"
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
      if device['virtual_name'] =~ /ephemeral\d+/
        {
          virtual_name: device['virtual_name'],
          device_name: device['device_name'],
        }
      else
        {
          device_name: device['device_name'],
          ebs: {
            volume_size: device['volume_size'],
            delete_on_termination: device['delete_on_termination'] || true,
            volume_type: device['volume_type'] || 'standard',
            iops: device['iops'],
            encrypted: device['encrypted'] ? true : nil
          },
        }
      end
    end
    config['block_device_mappings'] = mappings unless mappings.empty?
    config
  end

  def config_with_key_details(config)
    key = resource[:key_name] ? resource[:key_name] : false
    config['key_name'] = key if key
    config
  end

  def config_with_private_ip(config)
    config['private_ip_address'] = resource['private_ip_address'] if resource['private_ip_address'] && using_vpc?
    config
  end

  def config_with_public_interface(config)
    if resource[:associate_public_ip_address] == :true
      config[:network_interfaces] = [{
        device_index: 0,
        subnet_id: config[:subnet_id],
        groups: config[:security_group_ids],
        associate_public_ip_address: true,
      }]
      config[:subnet_id] = nil
      config[:security_group_ids] = nil
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
        instance_initiated_shutdown_behavior: resource[:instance_initiated_shutdown_behavior].to_s,
        iam_instance_profile: resource[:iam_instance_profile_arn] ?
          Hash['arn' => resource[:iam_instance_profile_arn]] :
          Hash['name' => resource[:iam_instance_profile_name]],
        placement: {
          availability_zone: resource[:availability_zone]
        },
        monitoring: {
          enabled: resource[:monitoring].to_s,
        }
      }

      config = config_with_key_details(config)
      config = config_with_devices(config)
      config = config_with_network_details(config)
      config = config_with_private_ip(config)
      config = config_with_public_interface(config)

      response = ec2.run_instances(config)

      instance_ids = response.instances.map(&:instance_id)

      with_retries(:max_tries => 5) do
        ec2.create_tags(
          resources: instance_ids,
          tags: tags_for_resource
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

  def destroy
    Puppet.info("Deleting instance #{name} in region #{target_region}")
    ec2 = ec2_client(target_region)
    ec2.terminate_instances(instance_ids: [instance_id])
    ec2.wait_until(:instance_terminated, instance_ids: [instance_id])
    @property_hash[:ensure] = :absent
  end
end

