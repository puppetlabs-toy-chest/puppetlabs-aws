require_relative '../../../puppet_x/puppetlabs/aws.rb'
require 'base64'
require 'retries'

Puppet::Type.type(:ec2_instance).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws
  confine feature: :retries

  mk_resource_methods

  def self.instances
    regions.collect do |region|
      instances = []
      ec2_client(region).describe_instances(filters: [
        {name: 'instance-state-name', values: ['pending', 'running', 'stopping', 'stopped']}
      ]).each do |response|
        response.data.reservations.each do |reservation|
          reservation.instances.each do |instance|
            hash = instance_to_hash(region, instance)
            instances << new(hash) if (hash[:name] and ! hash[:name].empty?)
          end
        end
      end
      instances
    end.flatten
  end

  read_only(:instance_id, :instance_type, :region, :user_data, :key_name,
            :availability_zones, :security_groups, :monitoring, :subnet)

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region
      end
    end
  end

  def self.instance_to_hash(region, instance)
    name_tag = instance.tags.detect { |tag| tag.key == 'Name' }
    monitoring = instance.monitoring.state == "enabled" ? true : false
    tags = {}
    instance.tags.each do |tag|
      tags[tag.key] = tag.value unless tag.key == 'Name'
    end
    subnet_name = nil
    if instance.subnet_id
      subnet_response = ec2_client(region).describe_subnets(subnet_ids: [instance.subnet_id])
      subnet_name_tag = subnet_response.data.subnets.first.tags.detect { |tag| tag.key == 'Name' }
    end
    subnet_name = subnet_name_tag ? subnet_name_tag.value : nil

    config = {
      name: name_tag ? name_tag.value : nil,
      instance_type: instance.instance_type,
      image_id: instance.image_id,
      instance_id: instance.instance_id,
      monitoring: monitoring,
      key_name: instance.key_name,
      availability_zone: instance.placement.availability_zone,
      ensure: instance.state.name.to_sym,
      tags: tags,
      region: region,
      hypervisor: instance.hypervisor,
      virtualization_type: instance.virtualization_type,
      security_groups: instance.security_groups.collect(&:group_name),
      subnet: subnet_name,
    }
    if instance.state.name == 'running'
      config[:public_dns_name] = instance.public_dns_name
      config[:private_dns_name] = instance.private_dns_name
      config[:public_ip_address] = instance.public_ip_address
      config[:private_ip_address] = instance.private_ip_address
    end
    config
  end

  def exists?
    dest_region = resource[:region] if resource
    Puppet.info("Checking if instance #{name} exists in region #{dest_region || region}")
    running? || stopped?
  end

  def running?
    dest_region = resource[:region] if resource
    Puppet.info("Checking if instance #{name} is running in region #{dest_region || region}")
    [:present, :pending, :running].include? @property_hash[:ensure]
  end

  def stopped?
    dest_region = resource[:region] if resource
    Puppet.info("Checking if instance #{name} is stopped in region #{dest_region || region}")
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
      if resource[:subnet].empty?
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

    if subnet.nil?
      raise Puppet::Error,
        "Security groups '#{groups.join(', ')}' not found in VPCs '#{vpc_groups.keys.join(', ')}'"
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
        placement: {
          availability_zone: resource[:availability_zone]
        },
        monitoring: {
          enabled: resource[:monitoring].to_s,
        }
      }

      key = resource[:key_name] ? resource[:key_name] : false
      config['key_name'] = key if key
      config = config_with_network_details(config)

      response = ec2.run_instances(config)

      instance_ids = response.instances.map(&:instance_id)

      with_retries(:max_tries => 5) do
        tags = resource[:tags] ? resource[:tags].map { |k,v| {key: k, value: v} } : []
        tags << {key: 'Name', value: name}
        ec2.create_tags(
          resources: instance_ids,
          tags: tags
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
    Puppet.info("Stopping instance #{name} in region #{resource[:region]}")
    ec2 = ec2_client(resource[:region])
    # Can't stop an instance that hasn't started yet
    ec2.wait_until(:instance_running, instance_ids: [@property_hash[:instance_id]])
    ec2.stop_instances(
      instance_ids: [@property_hash[:instance_id]]
    )
    @property_hash[:ensure] = :stopped
  end

  def tags=(value)
    Puppet.info("Updating tags for #{name} in region #{region}")
    ec2 = ec2_client(resource[:region])
    ec2.create_tags(
      resources: [instance_id],
      tags: value.collect { |k,v| { :key => k, :value => v } }
    ) unless value.empty?
    missing_tags = tags.keys - value.keys
    ec2.delete_tags(
      resources: [instance_id],
      tags: missing_tags.collect { |k| { :key => k } }
    ) unless missing_tags.empty?
  end

  def destroy
    Puppet.info("Deleting instance #{name} in region #{resource[:region]}")
    ec2 = ec2_client(resource[:region])
    ec2.terminate_instances(instance_ids: [instance_id])
    ec2.wait_until(:instance_terminated, instance_ids: [instance_id])
    @property_hash[:ensure] = :absent
  end
end

