require_relative '../../../puppet_x/puppetlabs/aws.rb'
require_relative '../../../puppet_x/puppetlabs/aws_ingress_rules_parser.rb'

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

  def self.format_ingress_rules(ec2, group)
    PuppetX::Puppetlabs::AwsIngressRulesParser.ip_permissions_to_rules_list(
      ec2, group[:ip_permissions], [group.group_id, group.group_name])
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

    self_ref  = [@property_hash[:id], name].compact
    fail "self ref #{self_ref.inspect} must contain id and name" unless self_ref.size == 2

    to_create.compact.each do |rule|
      ec2.authorize_security_group_ingress(
        group_id: @property_hash[:id],
        ip_permissions:
          PuppetX::Puppetlabs::AwsIngressRulesParser.rule_to_ip_permission_list(
            ec2, vpc_only_account?, rule, self_ref))
    end

    to_delete.compact.each do |rule|
      ec2.revoke_security_group_ingress(
        group_id: @property_hash[:id],
        ip_permissions: PuppetX::Puppetlabs::AwsIngressRulesParser.rule_to_ip_permission_list(
          ec2, vpc_only_account?, rule, self_ref))
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
