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

  read_only(:region, :description)

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region
      end
    end
  end

  def self.format_ingress_rules(client, group)
    group[:ip_permissions].collect do |rule|
      if rule.user_id_group_pairs.empty?
        {
          'protocol' => rule.ip_protocol,
          'port' => rule.to_port.to_i,
          'cidr' => rule.ip_ranges.first.cidr_ip
        }
      else
        rule.user_id_group_pairs.collect do |security_group|
          name = security_group.group_name
          if name.nil?
            group_response = client.describe_security_groups(
              group_ids: [security_group.group_id]
            )
            name = group_response.data.security_groups.first.group_name
          end
          {
            'security_group' => name
          }
        end
      end
    end.flatten.uniq
  end

  def self.security_group_to_hash(region, group)
    ec2 = ec2_client(region)
    vpc_name = nil
    if group.vpc_id
      vpc_response = ec2.describe_vpcs(
        vpc_ids: [group.vpc_id]
      )
      vpc_name = if vpc_response.data.vpcs.empty?
        nil
      elsif vpc_response.data.vpcs.first.to_hash.keys.include?(:group_name)
        vpc_response.data.vpcs.first.group_name
      elsif vpc_response.data.vpcs.first.to_hash.keys.include?(:tags)
        vpc_name_tag = vpc_response.data.vpcs.first.tags.detect { |tag| tag.key == 'Name' }
        vpc_name_tag ? vpc_name_tag.value : nil
      end
    end
    {
      id: group.group_id,
      name: group[:group_name],
      id: group[:group_id],
      description: group[:description],
      ensure: :present,
      ingress: format_ingress_rules(ec2, group),
      vpc: vpc_name,
      region: region,
      tags: tags_for(group),
    }
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
      group_name: name,
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

    ec2.create_tags(
      resources: [response.group_id],
      tags: tags_for_resource
    ) if resource[:tags]

    @property_hash[:id] = response.group_id
    rules = resource[:ingress]
    authorize_ingress(rules)
    @property_hash[:ensure] = :present
  end

  def authorize_ingress(new_rules, existing_rules=[])
    ec2 = ec2_client(resource[:region])
    new_rules = [new_rules] unless new_rules.is_a?(Array)

    to_create = new_rules - existing_rules
    to_delete = existing_rules - new_rules


    to_create.reject(&:nil?).each do |rule|
      if rule.key? 'security_group'
        source_group_name = rule['security_group']
        group_response = ec2.describe_security_groups(filters: [
          {name: 'group-name', values: [source_group_name]},
        ])
        fail("No groups found called #{source_group_name}") if group_response.data.security_groups.count == 0
        source_group_id = group_response.data.security_groups.first.group_id
        Puppet.warning "Multiple groups found called #{source_group_name}, using #{source_group_id}" if group_response.data.security_groups.count > 1

        permissions = ['tcp', 'udp', 'icmp'].collect do |protocol|
          {
            ip_protocol: protocol,
            to_port: protocol == 'icmp' ? -1 : 65535,
            from_port: protocol == 'icmp' ? -1 : 1,
            user_id_group_pairs: [{
              group_id: source_group_id
            }]
          }
        end

        ec2.authorize_security_group_ingress(
          group_id: @property_hash[:id],
          ip_permissions: permissions
        )
      else
        ec2.authorize_security_group_ingress(
          group_id: @property_hash[:id],
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
          group_id: @property_hash[:id],
          source_security_group_name: rule['security_group']
        )
      else
        ec2.revoke_security_group_ingress(
          group_id: @property_hash[:id],
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

  def destroy
    Puppet.info("Deleting security group #{name} in region #{resource[:region]}")
    ec2_client(resource[:region]).delete_security_group(
      group_id: @property_hash[:id]
    )
    @property_hash[:ensure] = :absent
  end
end
