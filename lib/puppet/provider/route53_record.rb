require_relative '../../puppet_x/puppetlabs/aws'

class Puppet::Provider::Route53Record < PuppetX::Puppetlabs::Aws

  def self.instances
    begin
      zones_response = route53_client.list_hosted_zones()
      records = []
      zones_response.data.hosted_zones.each do |zone|
        route53_client.list_resource_record_sets(hosted_zone_id: zone.id).each do |records_response|
        records_response.data.resource_record_sets.each do |record|
          records << new({
            name: record.name,
            ensure: :present,
            zone: zone.name,
            ttl: record.ttl,
            values: record.resource_records.map(&:value),
          }) if record.type == record_type
        end
      end
    end
      records
    rescue Timeout::Error, StandardError => e
      raise PuppetX::Puppetlabs::FetchingAWSDataError.new("Route 53", self.resource_type.name.to_s, e.message)
    end
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end

  def exists?
    Puppet.info("Checking if #{self.class.record_type} record #{name} exists")
    @property_hash[:ensure] == :present
  end

  def record_hash(action)
    values = resource[:values] || @property_hash[:values]
    records = values ? values.map { |v| {value: v} } : []
    ttl = resource[:ttl] || @property_hash[:ttl]
    {
      hosted_zone_id: zone_id,
      change_batch: {
        changes: [{
          action: action,
          resource_record_set: {
            name: resource[:name],
            type: self.class.record_type,
            ttl: ttl,
            resource_records: records,
          }
        }]
      }
    }
  end

  def zone_id
    zone_name = resource[:zone] || @property_hash[:zone]
    zones = route53_client.list_hosted_zones.data.hosted_zones.select { |zone|
      zone.name == zone_name
    }
    fail "No Zone named #{zone_name}" if zones.count < 1
    fail "Multiple Zone records found for #{zone_name}" if zones.count > 1
    zones.first.id
  end

  def update
    Puppet.info("Updating #{self.class.record_type} record #{name}")
    route53_client.change_resource_record_sets(
      record_hash('UPSERT')
    )
  end

  def create
    Puppet.info("Creating #{self.class.record_type} record #{name}")
    route53_client.change_resource_record_sets(
      record_hash('UPSERT')
    )
    @property_hash[:ensure] = :present
  end

  def destroy
    Puppet.info("Deleting #{self.class.record_type} record #{name}")
    route53_client.change_resource_record_sets(
      record_hash('DELETE')
    )
    @property_hash[:ensure] = :absent
  end
end
