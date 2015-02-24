require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:ec2_securitygroup).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

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

  read_only(:region, :description)

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region
      end
    end
  end

  def self.format_ingress_rules(group)
    group[:ip_permissions].collect do |rule|
      if rule.user_id_group_pairs.empty?
        {
          'protocol' => rule.ip_protocol,
          'port' => rule.to_port.to_i,
          'cidr' => rule.ip_ranges.first.cidr_ip
        }
      else
        rule.user_id_group_pairs.collect do |security_group|
          {
            'security_group' => security_group.group_name
          }
        end
      end
    end.flatten.uniq
  end

  def self.security_group_to_hash(region, group)
    sg_hash = {
      name: group[:group_name],
      id: group[:group_id],
      description: group[:description],
      ensure: :present,
      ingress: format_ingress_rules(group),
      region: region,
    }
    if group[:vpc_id]
      # Is it possible to get a vpc_id that points nowhere, and get no response?
      if vpcs = ec2_client(region).describe_vpcs(vpc_ids: [group[:vpc_id]]).first.vpcs
        sg_hash[:vpc_name] = name_from_tag(vpcs.first)
      end
    end
    sg_hash
  end

  def exists?
    dest_region = resource[:region] if resource
    Puppet.info("Checking if security group #{name} exists in region #{dest_region || region}")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating security group #{name} in region #{resource[:region]}")
    ec2 = ec2_client(resource[:region])
    tags = resource[:tags] ? resource[:tags].map { |k,v| {key: k, value: v} } : []
    vpc_id = nil
    if resource[:vpc_name]
      if ! vpc_id = vpc_id_from_name(resource[:vpc_name])
        raise Puppet::Error, "The vpc '#{resource[:vpc_name]}' was not found"
      end
    end
    create_hash = {
      group_name: name,
      description: resource[:description]
    }
    create_hash[:vpc_id] = vpc_id if vpc_id
    response = ec2.create_security_group(create_hash)

    @property_hash[:ensure] = :present
    @property_hash[:id] = response.group_id

    ec2.create_tags(
      resources: [response.group_id],
      tags: tags
    ) unless tags.empty?

    rules = resource[:ingress]
    authorize_ingress(rules)
  end

  def authorize_ingress(new_rules, existing_rules=[])
    ec2 = ec2_client(resource[:region])
    new_rules = [new_rules] unless new_rules.is_a?(Array)

    to_create = new_rules - existing_rules
    to_delete = existing_rules - new_rules

    to_create.reject(&:nil?).each do |rule|
      if rule.key? 'security_group'
        ec2.authorize_security_group_ingress(
          group_id: id,
          source_security_group_name: rule['security_group']
        )
      else
        ec2.authorize_security_group_ingress(
          group_id: id,
          ip_permissions: [{
            ip_protocol: rule['protocol'],
            to_port: rule['port'].to_i,
            from_port: rule['port'].to_i,
            ip_ranges: [{
              cidr_ip: rule['cidr']
            }]
          }]
        )
      end
    end

    to_delete.reject(&:nil?).each do |rule|
      if rule.key? 'security_group'
         ec2.revoke_security_group_ingress(
          group_id: id,
          source_security_group_name: rule['security_group']
        )
      else
        ec2.revoke_security_group_ingress(
          group_id: id,
          ip_permissions: [{
            ip_protocol: rule['protocol'],
            to_port: rule['port'].to_i,
            from_port: rule['port'].to_i,
            ip_ranges: [{
              cidr_ip: rule['cidr']
            }]
          }]
        )
      end
    end

  end

  def ingress=(value)
    authorize_ingress(value, @property_hash[:ingress])
  end

  def vpc_name=(value)
    raise Puppet::Error, "vpc_name may only be set upon create"
  end

  def destroy
    Puppet.info("Deleting security group #{name} in region #{resource[:region]}")
    ec2_client(resource[:region]).delete_security_group(
      group_id: id
    )
    @property_hash[:ensure] = :absent
  end

  def vpc_id_from_name(name)
    vpc_ids = ec2_client(resource[:region]).describe_vpcs(filters: [
      {name: 'tag-key',   values: ['Name']},
      {name: 'tag-value', values: [name]},
    ]).collect do |response|
      response.vpcs.collect do |vpc|
        vpc.vpc_id if vpc.vpc_id
      end
    end.flatten
    p vpc_ids
    if vpc_ids.length > 1
      Puppet.warning "Ambiguous VPC name '#{name}' resolves to VPC IDs #{vpc_ids.join(', ')} - using #{vpc_ids.first}"
    end
    vpc_ids.first
  end
end
