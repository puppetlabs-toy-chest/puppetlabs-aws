require_relative '../../../puppet_x/puppetlabs/aws'
require_relative '../../../puppet_x/puppetlabs/aws_ingress_rules_parser'

Puppet::Type.type(:ec2_securitygroup).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods
  remove_method :tags=

  def self.instances
    regions.collect do |region|
      begin
        groups = []
        ec2_client(region).describe_security_groups.each do |response|
          response.data.security_groups.collect do |group|
            groups << new(security_group_to_hash(region, group))
          end
        end
        groups
      rescue StandardError => e
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

  def self.prepare_ingress_rule_for_puppet(client, rule, group = nil, cidr = nil)
    config = {
      'protocol' => rule.ip_protocol,
      'from_port' => rule.from_port.to_i,
      'to_port' => rule.to_port.to_i,
    }
    if group
      name = group.group_name
      if name.nil?
        group_response = client.describe_security_groups(filters: [
          {name: 'group-id', values: [group.group_id]}
        ])
        groups = group_response.data.security_groups
        name = groups.empty? ? nil : groups.first.group_name
      end
      config['security_group'] = name
    end
    config['cidr'] = cidr.cidr_ip if cidr
    config
  end

  def self.format_ingress_rules(client, group)
    rules = []
    group[:ip_permissions].each do |rule|
      addition = []
      rule.user_id_group_pairs.each do |security_group|
        addition << prepare_ingress_rule_for_puppet(client, rule, security_group)
      end
      rule.ip_ranges.each do |cidr|
        addition << prepare_ingress_rule_for_puppet(client, rule, nil, cidr)
      end
      addition << prepare_ingress_rule_for_puppet(client, rule) if addition.empty?
      rules << addition
    end
    rules.flatten.uniq.compact
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
    name = group[:group_name]
    name = "#{vpc_name}::#{name}" if vpc_name && name == 'default'
    {
      name: name,
      group_name: group[:group_name],
      id: group[:group_id],
      description: group[:description],
      ensure: :present,
      ingress: format_ingress_rules(ec2, group),
      vpc: vpc_name,
      vpc_id: group.vpc_id,
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
      permission[:from_port] = protocol == 'icmp' ? -1 : from_port.to_i
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
        msg = "No groups found called #{source_group_name}"
        msg = msg + " in #{@property_hash[:vpc]}"
        fail(msg) if match_count == 0
        source_group_id = group_response.data.security_groups.first.group_id
        Puppet.warning "#{match_count} groups found called #{source_group_name}, using #{source_group_id}" if match_count > 1

        permission[:user_id_group_pairs] = [{
          group_id: source_group_id
        }]
      elsif rule.key? 'cidr'
        permission[:ip_ranges] = [{cidr_ip: rule['cidr']}]
      end
      rule_hash[:ip_permissions] << permission
    end

    rule_hash
  end

  def authorize_ingress(new_rules, existing_rules=[])
    ec2 = ec2_client(resource[:region])
    new_rules = [new_rules] unless new_rules.is_a?(Array)

    parser = PuppetX::Puppetlabs::AwsIngressRulesParser.new(new_rules)
    to_create = parser.rules_to_create(existing_rules)
    to_delete = parser.rules_to_delete(existing_rules)

    to_delete.reject(&:nil?).each do |rule|
      ec2.revoke_security_group_ingress(prepare_ingress_for_api(rule))
    end

    to_create.each do |rule|
      ec2.authorize_security_group_ingress(prepare_ingress_for_api(rule))
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
