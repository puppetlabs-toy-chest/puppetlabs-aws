require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:ec2_vpc_internet_gateway).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws
  confine feature: :retries

  mk_resource_methods
  remove_method :tags=

  def self.instances
    regions.collect do |region|
      begin
        response = ec2_client(region).describe_internet_gateways()
        gateways = []
        response.data.internet_gateways.each do |gateway|
          hash = gateway_to_hash(region, gateway)
          gateways << new(hash) if has_name?(hash)
        end
        gateways
      rescue Timeout::Error, StandardError => e
        raise PuppetX::Puppetlabs::FetchingAWSDataError.new(region, self.resource_type.name.to_s, e.message)
      end
    end.flatten
  end

  read_only(:region, :vpcs)

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region
      end
    end
  end

  def self.gateway_to_hash(region, gateway)
    assigned_name = name_from_tag(gateway)
    return {} unless assigned_name
    vpc_name = nil
    vpc_id = nil
    if assigned_name
      gateway.attachments.each do |attachment|
        name = vpc_name_from_id(region, attachment.vpc_id)
        unless name.nil?
          vpc_name = name
          vpc_id = attachment.vpc_id
        end
      end
    end

    {
      name: assigned_name,
      vpc: vpc_name,
      vpc_id: vpc_id,
      id: gateway.internet_gateway_id,
      ensure: :present,
      region: region,
      tags: tags_for(gateway),
    }
  end

  def exists?
    Puppet.debug("Checking if internet gateway #{name} exists in #{target_region}")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating internet gateway #{name} in #{target_region}")
    ec2 = ec2_client(target_region)
    vpc_response = ec2.describe_vpcs(filters: [
      {name: "tag:Name", values: [resource[:vpc]]},
    ])
    response = ec2.create_internet_gateway()
    id = response.data.internet_gateway.internet_gateway_id
    vpc_response.data.vpcs.each do |vpc|
      ec2.attach_internet_gateway(
        internet_gateway_id: id,
        vpc_id: vpc.vpc_id,
      )
    end

    with_retries(:max_tries => 5) do
      ec2.create_tags(
        resources: [id],
        tags: tags_for_resource,
      )
    end
  end

  def destroy
    Puppet.info("Deleting internet gateway #{name} in #{target_region}")
    ec2 = ec2_client(target_region)
    if @property_hash[:vpc_id]
      ec2.detach_internet_gateway(
        internet_gateway_id: @property_hash[:id],
        vpc_id: @property_hash[:vpc_id],
      )
    end
    ec2.delete_internet_gateway(internet_gateway_id: @property_hash[:id])
    @property_hash[:ensure] = :absent
  end
end
