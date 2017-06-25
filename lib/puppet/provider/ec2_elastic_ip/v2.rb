require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:ec2_elastic_ip).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    regions.collect do |region|
      begin
        ec2 = ec2_client(region)
        ec2.describe_addresses.addresses.collect do |address|
          instance_name = nil
          unless address.instance_id.nil? || address.instance_id.empty?
            instances = ec2.describe_instances(instance_ids: [address.instance_id]).collect do |response|
              response.data.reservations.collect do |reservation|
                reservation.instances.collect do |instance|
                  instance
                end
              end.flatten
            end.flatten
            name_tag = instances.first.tags.detect { |tag| tag.key == 'Name' }
            instance_name = name_tag ? name_tag.value : nil
          end
          new({
            name: address.public_ip,
            instance_id: address.instance_id,
            instance: instance_name,
            allocation_id: address.allocation_id,
            association_id: address.association_id,
            domain: address.domain,
            ensure: instance_name ? :attached : :detached,
            region: region,
          })
        end
      rescue Timeout::Error, StandardError => e
        raise PuppetX::Puppetlabs::FetchingAWSDataError.new(region, self.resource_type.name.to_s, e.message)
      end
    end.flatten
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]
        resource.provider = prov if resource[:region] == prov.region
      end
    end
  end

  def exists?
    Puppet.debug("Checking if Elastic IP #{name} is associated")
    @property_hash[:ensure] == :attached
  end

  def create
    Puppet.info("Creating association for #{name}")
    ec2 = ec2_client(resource[:region])
    response = ec2.describe_instances(filters: [
      {name: 'tag:Name', values: [resource[:instance]]},
      {name: 'instance-state-name', values: ['pending','running']}
    ])
    instance_ids = response.reservations.map(&:instances).flatten.map(&:instance_id)

    fail "No pending or running instance found named #{resource[:instance]}" if instance_ids.empty?
    if instance_ids.count > 1
      Puppet.warning "Multiple instances found named #{resource[:instance]}, using #{instance_ids.first}"
    end

    config = if @property_hash[:domain] == 'vpc'
      {
        instance_id: instance_ids.first,
        allocation_id: @property_hash[:allocation_id],
        allow_reassociation: true,
      }
    else
      {
        instance_id: instance_ids.first,
        public_ip: name,
      }
    end

    ec2.wait_until(:instance_running, instance_ids: [instance_ids.first])
    ec2.associate_address(config)
    @property_hash[:instance] = resource[:instance]
    @property_hash[:ensure] = :attached
  end

  def flush
    create unless @property_hash[:ensure] == :detached
  end

  def destroy
    Puppet.info("Deleting association with #{name}")
    config = if @property_hash[:domain] == 'vpc'
      {association_id: @property_hash[:association_id]}
    else
      {public_ip: name}
    end
    ec2_client(resource[:region]).disassociate_address(config)
    @property_hash[:instance] = nil
    @property_hash[:ensure] = :detached
  end
end
