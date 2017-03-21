require_relative '../../../puppet_x/puppetlabs/aws'
require_relative '../../../puppet_x/puppetlabs/aws_ingress_rules_parser'

Puppet::Type.type(:ec2_securitygroup).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods
  remove_method :tags=

  def self.instances
    regions.collect do |region|
      begin
        vpc_names = {}
        vpc_response = ec2_client(region).describe_vpcs()
        vpc_response.data.vpcs.each do |vpc|
          vpc_name = name_from_tag(vpc)
          vpc_names[vpc.vpc_id] = vpc_name if vpc_name
        end

        group_names = {}
        groups = ec2_client(region).describe_security_groups.collect do |response|
          response.data.security_groups.collect do |group|
            group_names[group.group_id] = group.group_name || name_from_tag(group)
            group
          end
        end.flatten
        groups.collect do |group|
          new(security_group_to_hash(region, group, group_names, vpc_names))
        end.compact
      rescue Timeout::Error, StandardError => e
        raise PuppetX::Puppetlabs::FetchingAWSDataError.new(region, self.resource_type.name.to_s, e.message)
      end
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

  def self.prepare_ingress_rule_for_puppet(region, rule, groups, group = nil, cidr = nil)
    config = {
      'protocol' => rule.ip_protocol,
      'from_port' => rule.from_port.to_i,
      'to_port' => rule.to_port.to_i,
    }
    if group
      name = group.group_name
      if name.nil?
        name = groups[group.group_id]
      end
      config['security_group'] = name
    end
    config['cidr'] = cidr.cidr_ip if cidr
    config
  end

  def self.format_ingress_rules(region, group, groups)
    rules = []
    group[:ip_permissions].each do |rule|
      addition = []
      rule.user_id_group_pairs.each do |security_group|
        addition << prepare_ingress_rule_for_puppet(region, rule, groups, security_group)
      end
      rule.ip_ranges.each do |cidr|
        addition << prepare_ingress_rule_for_puppet(region, rule, groups, nil, cidr)
      end
      addition << prepare_ingress_rule_for_puppet(region, rule, groups) if addition.empty?
      rules << addition
    end
    rules.flatten.uniq.compact
  end

  def self.security_group_to_hash(region, group, groups, vpcs)
    {
      id: group.group_id,
      name: group.group_name,
      description: group.description,
      ensure: :present,
      ingress: format_ingress_rules(region, group, groups),
      vpc: vpcs[group.vpc_id],
      vpc_id: group.vpc_id,
      region: region,
      tags: tags_for(group),
    }
  end

  def exists?
    Puppet.debug("Checking if security group #{name} exists in region #{target_region}")
    @property_hash[:ensure] == :present
  end

  def ec2
    ec2_client(target_region)
  end

  def create
    Puppet.info("Creating security group #{name} in region #{target_region}")
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
      @property_hash[:vpc_id] = vpc_id
      @property_hash[:vpc] = vpc_name
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

  def prepare_ingress_for_api(rule)
    ec2 = ec2_client(resource[:region])
    from_port ||= rule['from_port'] || rule['port'] || 1
    to_port ||= rule['to_port'] || rule['port'] || 65535
    rule_hash = {
      group_id: @property_hash[:id],
      ip_permissions: []
    }

    protocols = rule.key?('protocol') ? Array(rule['protocol']) : ['tcp', 'udp', 'icmp']

    protocols.each do |protocol|
      permission = {
        ip_protocol: protocol,
      }
      permission[:to_port] = protocol == 'icmp' ? -1 : to_port.to_i
      permission[:from_port] = from_port.to_i
      if rule.key? 'security_group'
        source_group_name = rule['security_group']

        filters = [ {name: 'group-name', values: [source_group_name]} ]

        if @property_hash[:vpc_id]
          filters.push( {name: 'vpc-id', values: [@property_hash[:vpc_id]]} )
        elsif vpc_only_account?
          response = ec2.describe_security_groups(group_ids: [@property_hash[:id]])
          vpc_id = response.data.security_groups.first.vpc_id
          filters.push( {name: 'vpc-id', values: [vpc_id]} )
        end

        group_response = ec2.describe_security_groups(filters: filters)
        match_count = group_response.data.security_groups.count
        if match_count == 0
          Puppet.warning("No groups found called #{source_group_name} in #{@property_hash[:vpc]}; skipping rule")
        else
          source_group_id = group_response.data.security_groups.first.group_id
          Puppet.warning "#{match_count} groups found called #{source_group_name}, using #{source_group_id}" if match_count > 1

          permission[:user_id_group_pairs] = [{
            group_id: source_group_id
          }]
        end
      elsif rule.key? 'cidr'
        permission[:ip_ranges] = [{cidr_ip: rule['cidr']}]
      end

      # Skip the permission if it has no peer.
      rule_hash[:ip_permissions] << permission unless (permission.keys & [:user_id_group_pairs, :ip_ranges]).empty?
    end

    rule_hash[:ip_permissions].any? ? rule_hash : nil
  end

  def authorize_ingress(new_rules, existing_rules=[])
    ec2 = ec2_client(resource[:region])
    new_rules = [new_rules] unless new_rules.is_a?(Array)

    parser = PuppetX::Puppetlabs::AwsIngressRulesParser.new(new_rules)
    to_create = parser.rules_to_create(existing_rules)
    to_delete = parser.rules_to_delete(existing_rules)

    to_delete.compact.each do |rule|
      prepared_rule = prepare_ingress_for_api(rule) and
        ec2.revoke_security_group_ingress(prepared_rule)
    end

    to_create.compact.each do |rule|
      prepared_rule = prepare_ingress_for_api(rule) and
        ec2.authorize_security_group_ingress(prepared_rule)
    end
  end

  def ingress=(value)
    authorize_ingress(value, @property_hash[:ingress])
  end

  def destroy
    Puppet.info("Deleting security group #{name} in region #{target_region}")
    ec2.delete_security_group(
      group_id: @property_hash[:id]
    )
    @property_hash[:ensure] = :absent
  end
end
