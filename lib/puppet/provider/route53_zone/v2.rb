require_relative '../../../puppet_x/puppetlabs/aws.rb'
require 'securerandom'

Puppet::Type.type(:route53_zone).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  read_only(:id, :record_count, :is_private)

  mk_resource_methods

  def initialize(value={})
    super(value)
    @property_flush = {}
  end

  def self.instances
    zones = []
    list_opts = {max_items: 100}

    # Loop over paginated API responses.
    loop do
      response = route53_client.list_hosted_zones()

      # Loop over each zone in one API response.
      response.data.hosted_zones.collect do |zone|
        # Basic zone data.
        id = zone.id.sub(/^\/hostedzone\//, '')
        zone_hash = {
          name: zone.name,
          ensure: :present,
          is_private: zone.config['private_zone'],
          id: id,
          record_count: zone.resource_record_set_count,
          comment: zone.config['comment'],
        }

        # Zone tags.
        tags = route53_client.list_tags_for_resource({
          resource_type: 'hostedzone',
          resource_id: id,
        })
        zone_hash[:tags] = self.tags_for(tags.resource_tag_set)

        # VPCs for private zones.
        if zone_hash[:is_private]
          zone_info = route53_client.get_hosted_zone(id: zone_hash[:id])
          # Yes, this method is actually named 'vp_cs'.
          zone_hash[:vpcs] = zone_info.vp_cs.collect do |vpc|
            region = vpc.vpc_region
            name_tag = self.vpc_name_from_id(region, vpc.vpc_id)

            # Use ID for when there is no name.
            vpc_name = name_tag ? name_tag : vpc.vpc_id

            {
              'region' => region,
              'vpc' => vpc_name,
            }
          end
        end

        zones << new(zone_hash)
      end

      break unless response.is_truncated
      list_ops[:marker] = response.next_marker
    end

    zones
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end

  def exists?
    Puppet.debug("Checking if zone #{name} exists")
    @property_hash[:ensure] == :present
  end

  def create
    reference = SecureRandom.hex
    Puppet.info("Creating zone #{name} with #{reference}")

    zone = {
      name: name,
      caller_reference: reference,
      hosted_zone_config: {
        comment: resource[:comment].to_s,
        private_zone: resource[:is_private],
      },
    }

    if resource[:is_private]
      vpcs = discover_vpcs(resource[:vpcs])

      fail "No VPCs found to associate with Route53 zone '#{name}'." if vpcs.empty?

      vpc_region = vpcs.first[:region]
      vpc_name = vpcs.first[:name]

      # Add only first VPC to the creation request, as it only accepts one.
      zone[:vpc] = {
        vpc_region: vpcs.first[:region],
        vpc_id: vpcs.first[:id],
      }

      # This message is here to match those from additional VPCs, otherwise it
      # looks like this one VPC was skipped.
      Puppet.info("Associating VPC '#{vpc_name}' in #{vpc_region} with Route53 zone '#{name}'.")
    end

    create_resp = route53_client.create_hosted_zone(zone)

    @property_hash[:ensure] = :present
    @property_hash[:id] = create_resp.hosted_zone.id.sub(/^\/hostedzone\//, '')
    @property_hash[:record_count] = create_resp.hosted_zone.resource_record_set_count

    @property_flush[:tags] = resource[:tags] if resource[:tags]

    if resource[:is_private]
      @property_hash[:vpcs] = [
        {
          'region' => vpc_region,
          'vpc' => vpc_name,
        },
      ]
      @property_flush[:vpcs] = resource[:vpcs]
    end
  end

  def discover_vpcs(vpcs)
    vpcs.collect do |vpc|
      region = vpc['region']
      vpc_id = self.class.vpc_id_from_name(region, vpc['vpc'])

      unless vpc_id
        Puppet.warning("VPC '#{vpc['vpc']}' in #{vpc['region']} associated with Route53 zone '#{name}' not found.")
        nil
        next
      end

      {
        region: region,
        name: vpc['vpc'],
        id: vpc_id,
      }
    end.compact
  end

  def comment=(value)
    Puppet.debug("Updating comment for Route53 zone: #{name}")
    route53_client.update_hosted_zone_comment(
      id: @property_hash[:id],
      comment: resource[:comment].to_s,
    )
  end

  def tags=(value)
    @property_flush[:tags] = value
  end

  def vpcs=(value)
    @property_flush[:vpcs] = value
  end

  def flush
    if @property_hash[:ensure] != :absent
      if @property_flush.has_key?(:tags)
        Puppet.debug("Updating tags for Route53 zone: #{name}")
        change_request = {
          resource_id: @property_hash[:id],
          resource_type: 'hostedzone',
        }

        updated_tags = (resource[:tags].to_a - @property_hash[:tags].to_a).to_h
        unless updated_tags.empty?
          change_request[:add_tags] = updated_tags.map { |k,v| {key: k, value: v} }
        end

        removed_tags = @property_hash[:tags].keys - resource[:tags].keys
        unless removed_tags.empty?
          change_request[:remove_tag_keys] = removed_tags
        end

        route53_client.change_tags_for_resource(change_request)
      end

      if @property_flush.has_key?(:vpcs) and resource[:is_private]
        Puppet.debug("Updating VPC associations for Route53 zone: #{name}")

        vpcs_add = discover_vpcs(resource[:vpcs] - @property_hash[:vpcs])
        vpcs_add.each do |vpc|
          Puppet.info("Associating VPC '#{vpc[:name]}' in #{vpc[:region]} with Route53 zone '#{name}'.")
          route53_client.associate_vpc_with_hosted_zone(
            hosted_zone_id: @property_hash[:id],
            vpc: {
              vpc_region: vpc[:region],
              vpc_id: vpc[:id],
            }
          )
        end

        vpcs_remove = discover_vpcs(@property_hash[:vpcs] - resource[:vpcs])
        vpcs_remove.each do |vpc|
          Puppet.info("Disassociating VPC '#{vpc[:name]}' in #{vpc[:region]} from Route53 zone '#{name}'.")
          route53_client.disassociate_vpc_from_hosted_zone(
            hosted_zone_id: @property_hash[:id],
            vpc: {
              vpc_region: vpc[:region],
              vpc_id: vpc[:id],
            }
          )
        end
      end
    end
  end

  def destroy
    Puppet.info("Deleting zone #{name}")
    route53_client.delete_hosted_zone(id: @property_hash[:id])
    @property_hash[:ensure] = :absent
  end
end
