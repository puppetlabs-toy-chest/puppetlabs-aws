require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:ec2_securitygroup).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    []
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] && resource[:region] == prov.region
        resource.provider = prov
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
    Puppet.info("Checking if security group #{name} exists in region #{resource[:region]}")

    if self.provider == :absent
      response = ec2_client(region: resource[:region]).describe_security_groups(filters: [
        {name: 'group-name', values: [name]},
      ])

      if ! response.security_groups.empty?
        group = response.security_groups.first
        @property_hash = self.class.security_group_to_hash(resource[:region], group)
        provider = self.class.new(@property_hash)
      end
    end

    found = @property_hash[:ensure] == :present
    Puppet.info("Security Group #{name} already exists in region #{resource[:region]}") if found
    found
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
