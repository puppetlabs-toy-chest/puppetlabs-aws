require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:ec2_vpc_dhcp_options).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws
  confine feature: :retries

  mk_resource_methods
  remove_method :tags=

  def self.instances
    regions.collect do |region|
      begin
        options = []
        ec2_client(region).describe_dhcp_options.collect do |response|
          response.data.dhcp_options.each do |item|
            hash = dhcp_option_to_hash(region, item)
            options << new(hash) if has_name?(hash)
          end
        end
        options
      rescue Timeout::Error, StandardError => e
        raise PuppetX::Puppetlabs::FetchingAWSDataError.new(region, self.resource_type.name.to_s, e.message)
      end
    end.flatten
  end

  read_only(:domain_name, :ntp_servers, :region, :domain_name_servers, :netbios_name_servers, :netbios_node_type)

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]  # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov
      end
    end
  end

  def self.dhcp_option_to_hash(region, option)
    config = {}
    option.dhcp_configurations.each do |conf|
      config[conf[:key]] = conf[:values].collect(&:value)
    end
    domain_name = config.keys.include?('domain-name') ? config['domain-name'].first.split(' ') : nil
    node_type = config.keys.include?('netbios-node-type') ? config['netbios-node-type'].first : nil
    {
      name: name_from_tag(option),
      id: option.dhcp_options_id,
      region: region,
      ensure: :present,
      domain_name: domain_name,
      ntp_servers: config['ntp-servers'],
      domain_name_servers: config['domain-name-servers'],
      netbios_name_servers: config['netbios-name-servers'],
      netbios_node_type: node_type,
      tags: tags_for(option),
    }
  end

  def exists?
    Puppet.debug("Checking if DHCP options #{name} exists in region #{target_region}")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating DHCP options #{name} in region #{target_region}")
    ec2 = ec2_client(target_region)

    options = []
    ['domain_name', 'ntp_servers', 'domain_name_servers', 'netbios_name_servers', 'netbios_node_type'].each do |key|
      value = resource[key.to_sym]
      value = value.join(' ') if key.eql?('domain_name') and value.is_a?(Array)
      options << {:key => key.gsub('_', '-'), :values => Array(value)} if value
    end

    response = ec2.create_dhcp_options(
      dhcp_configurations: options
    )

    with_retries(:max_tries => 5) do
      ec2.create_tags(
        resources: [response.data.dhcp_options.dhcp_options_id],
        tags: tags_for_resource
      )
    end

    @property_hash[:ensure] = :present
  end

  def destroy
    Puppet.info("Destroying DHCP options #{name} in #{target_region}")
    ec2_client(target_region).delete_dhcp_options(
      dhcp_options_id: @property_hash[:id]
    )
    @property_hash[:ensure] = :absent
  end
end
