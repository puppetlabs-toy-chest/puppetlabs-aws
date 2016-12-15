require_relative '../../puppet_x/puppetlabs/aws'

class Puppet::Provider::Route53Record < PuppetX::Puppetlabs::Aws

  def self.instances
    begin
      zones_response = route53_client.list_hosted_zones()
      records = []
      zones_response.data.hosted_zones.each do |zone|
        route53_client.list_resource_record_sets(hosted_zone_id: zone.id).each do |records_response|
          records_response.data.resource_record_sets.each do |record|

            resource_record = {
              name: record.name,
              ensure: :present,
              zone: zone.name,
              ttl: record.ttl,
              values: record.resource_records.map(&:value),
            }

            unless record.alias_target.is_a? NilClass
              resource_record[:alias_target] = record.alias_target.dns_name
              resource_record[:alias_target_zone] = record.alias_target.hosted_zone_id
            end

            records << new(resource_record) if record.type == record_type
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
    Puppet.debug("Checking if #{self.class.record_type} record #{name} exists")
    @property_hash[:ensure] == :present
  end

  def record_hash(action)
    values = resource[:values]
    records = values ? values.map { |v| {value: v} } : []
    alias_target = resource[:alias_target]
    alias_target_zone = resource[:alias_target_zone]
    ttl = resource[:ttl] || @property_hash[:ttl]
    data = {
      hosted_zone_id: zone_id,
      change_batch: {
        changes: [{
          action: action,
          resource_record_set: {
            name: resource[:name],
            type: self.class.record_type,
          }
        }]
      }
    }

    if alias_target and not records.empty?
      fail('route53_record property conflict detected.  route53_record
           resources must have only one pair of properties: ("values" + "ttl")
           set, or ("alias_target" + "alias_target_zone set").')
    end

    if alias_target and alias_target_zone
      alias_target_hash = {
        hosted_zone_id: alias_target_zone,
        dns_name: alias_target,
        evaluate_target_health: false,
      }

      data[:change_batch][:changes][0][:resource_record_set][:alias_target] = alias_target_hash
    elsif alias_target or alias_target_zone
      fail('Management of alias_target requires both alias_target and
                     alias_target_zone parameters.')
    elsif not records.empty?
      data[:change_batch][:changes][0][:resource_record_set][:resource_records] = records
      # TTL is here because it should be omitted from the request when we're managing the alias_target
      data[:change_batch][:changes][0][:resource_record_set][:ttl] = ttl
    end

    data
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
