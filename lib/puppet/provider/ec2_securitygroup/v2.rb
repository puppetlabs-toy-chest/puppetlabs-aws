require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:ec2_securitygroup).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    regions.collect do |region|
      response = ec2_client(region: region).describe_security_groups
      response.data.security_groups.collect do |group|
        new(security_group_to_hash(region, group))
      end
    end.flatten
  end

  read_only(:region)

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region
      end
    end
  end

  def self.security_group_to_hash(region, group)
    {
      name: group[:group_name],
      description: group[:description],
      ensure: :present,
      region: region,
    }
  end

  def exists?
    Puppet.info("Checking if security group #{name} exists in region #{region}")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating security group #{name} in region #{resource[:region]}")
    tags = resource[:tags] ? resource[:tags].map { |k,v| {key: k, value: v} } : []
    response = ec2_client(region: resource[:region]).create_security_group(
      group_name: name,
      description: resource[:description]
    )

    ec2_client(region: resource[:region]).create_tags(
      resources: [response.group_id],
      tags: tags
    ) unless tags.empty?

    rules = resource[:ingress]
    rules = [rules] unless rules.is_a?(Array)

    rules.reject(&:nil?).each do |rule|
      if rule.key? 'security_group'
        ec2_client(region: resource[:region]).authorize_security_group_ingress(
          group_name: name,
          source_security_group_name: rule['security_group']
        )
      else
        ec2_client(region: resource[:region]).authorize_security_group_ingress(
          group_name: name,
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

  def destroy
    Puppet.info("Deleting security group #{name} in region #{resource[:region]}")
    ec2_client(region: resource[:region]).delete_security_group(
      group_name: name
    )
    @property_hash[:ensure] = :absent
  end
end
