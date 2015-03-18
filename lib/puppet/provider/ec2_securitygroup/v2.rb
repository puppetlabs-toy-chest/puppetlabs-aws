require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:ec2_securitygroup).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods
  remove_method :tags=

  def self.instances
    regions.collect do |region|
      groups = []
      ec2_client(region).describe_security_groups.each do |response|
        response.data.security_groups.collect do |group|
          groups << new(security_group_to_hash(region, group))
        end
      end
      groups
    end.flatten
  end

  read_only(:name, :region, :description)

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region
      end
    end
  end

  def self.id_to_name(region, group_id)
    ec2 = ec2_client(region)

    group_response = ec2.describe_security_groups(
      filters: [{name: 'group-id', values: [group_id]}])

    group_response.data.security_groups.first.group_name
  end

  def self.format_ingress_rules(region, group)
    group[:ip_permissions].collect do |rule|
      {}.tap do |h|
        h['protocol'] = rule.ip_protocol

        h['cidr'] = rule.ip_ranges.map(&:cidr_ip)
        case h['cidr'].size
        when 0 then h.delete('cidr')
        when 1 then h['cidr'] = h['cidr'].first
        end

        h['port'] = [rule.from_port, rule.to_port].compact.map(&:to_s).uniq
        case h['port'].size
        when 0 then h.delete('port')
        when 1 then h['port'] = h['port'].first
        end

        h['security_group'] = rule.user_id_group_pairs.
          map {|ug| ug[:group_name] || id_to_name(region, ug[:group_id]) }.compact.
          reject {|g| group.group_name == g}
        case h['security_group'].size
        when 0 then h.delete('security_group')
        when 1 then h['security_group'] = h['security_group'].first
        end
      end
    end.flatten.uniq.compact
  end

  def self.security_group_to_hash(region, group)
    ec2 = ec2_client(region)
    vpc_name = nil
    if group.vpc_id
      vpc_response = ec2.describe_vpcs(filters: [
        {name: 'vpc-id', values: [group.vpc_id]}
      ])
      vpc_name = if vpc_response.data.vpcs.empty?
        nil
      elsif vpc_response.data.vpcs.first.to_hash.keys.include?(:group_name)
        vpc_response.data.vpcs.first.group_name
      elsif vpc_response.data.vpcs.first.to_hash.keys.include?(:tags)
        vpc_name_tag = vpc_response.data.vpcs.first.tags.detect { |tag| tag.key == 'Name' }
        vpc_name_tag ? vpc_name_tag.value : nil
      end
    end

    group_tags     = tags_from_data(group.tags)
    group_name_tag = group_tags.delete('Name')

    { id: group.group_id,
      name: group_name_tag ||
        (vpc_name ? "#{vpc_name}/#{group[:group_name]}" : group.group_id),
      group_name: group[:group_name],
      description: group[:description],
      ensure: :present,
      ingress: format_ingress_rules(region, group),
      vpc: vpc_name,
      region: region,
      tags: group_tags }
  end

  def exists?
    dest_region = resource[:region] if resource
    Puppet.info("Checking if security group #{name} exists in region #{dest_region || region}")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating security group #{name} in region #{resource[:region]}")
    ec2 = ec2_client(resource[:region])
    config = {
      group_name: resource[:group_name],
      description: resource[:description]
    }

    vpc_name = resource[:vpc]
    if vpc_name
      vpc_response = ec2.describe_vpcs(filters: [
        {name: 'tag:Name', values: [vpc_name]}
      ])
      fail("No VPC found called #{vpc_name}") if vpc_response.data.vpcs.count == 0
      vpc_id = vpc_response.data.vpcs.first.vpc_id
      Puppet.warning "Multiple VPCs found called #{vpc_name}, using #{vpc_id}" if vpc_response.data.vpcs.count > 1
      config[:vpc_id] = vpc_id
    end

    response = ec2.create_security_group(config)
    ec2.create_tags(resources: [response.group_id], tags: tags_for_resource)

    @property_hash[:id] = response.group_id
    authorize_ingress(resource[:ingress])
    @property_hash[:ensure] = :present
  end

  def id_or_name_to_id(group_id_or_name)
    return group_id_or_name if group_id_or_name =~ /^sg-/
    return @property_hash[:id] if group_id_or_name == @property_hash[:group_name]

    ec2 = ec2_client(@property_hash[:region])

    group_response = ec2.describe_security_groups(
      filters: [{name: 'group-name', values: [group_id_or_name]}])

    if group_response.data.security_groups.count == 0
      fail("No groups found with name: '#{group_id_or_name}'")
    elsif group_response.data.security_groups.count > 1
      Puppet.warning "Multiple groups found called #{group_id_or_name}"
    end

    group_response.data.security_groups.first.group_id
  end

  def rule_to_permission(rule)
    # fallback to current group id if cidr is absent
    sg = rule['security_group'] || (rule['cidr'] ? nil : @property_hash[:id])

    { ip_protocol: rule['protocol'],
      from_port:   Array(rule['port']).first,
      to_port:     Array(rule['port']).last,
      ip_ranges:   Array(rule['cidr']).map {|c| {cidr_ip: c}},
      user_id_group_pairs:
        Array(sg).map{|sgi| {group_id: id_or_name_to_id(sgi)} }}.
      delete_if {|k,v| v.is_a?(Array) && v.empty?}.
      delete_if {|k,v| v.nil?}
  end

  def authorize_ingress(new_rules, existing_rules=[])
    require 'pry'
    binding.pry
    ec2 = ec2_client(@property_hash[:region])
    new_rules = [new_rules] unless new_rules.is_a?(Array)

    to_create = new_rules - existing_rules
    to_delete = existing_rules - new_rules

    to_create.compact.each do |rule|
      ec2.authorize_security_group_ingress(
        group_id: @property_hash[:id],
        ip_permissions: [rule_to_permission(rule)])
    end

    to_delete.compact.each do |rule|
      ec2.revoke_security_group_ingress(
        group_id: @property_hash[:id],
        ip_permissions: [rule_to_permission(rule)])
    end
  end

  def ingress=(value)
    authorize_ingress(value, @property_hash[:ingress])
  end

  def destroy
    Puppet.info("Deleting security group #{name} in region #{resource[:region]}")
    ec2_client(resource[:region]).delete_security_group(
      group_id: @property_hash[:id]
    )
    @property_hash[:ensure] = :absent
  end
end
