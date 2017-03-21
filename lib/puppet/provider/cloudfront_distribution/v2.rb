require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:cloudfront_distribution).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  read_only(:arn, :id, :status)

  def self.instances
    dists = []
    list_opts = {max_items: 100}

    # Loop over paginated API responses.
    loop do
      dists_resp = cloudfront_client.list_distributions(list_opts).distribution_list

      # Loop over each distribution in one API response.
      dists_resp.items.each do |dist|
        tags = cloudfront_client.list_tags_for_resource({resource: dist.arn}).tags.items

        hash = self.distribution_to_hash(dist, tags)
        dists << new(hash) if hash[:name]
      end

      break unless dists_resp.is_truncated
      list_opts[:marker] = dists_resp.next_marker
    end

    dists.compact
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end

  def self.distribution_to_hash(dist, tags)
    {
      name: self.name_from_cloudfront_tags(tags),
      ensure: :present,
      arn: dist.arn,
      id: dist.id,
      status: dist.status,
      comment: dist.comment,
      enabled: dist.enabled,
      price_class: dist.price_class.sub(/^PriceClass_/, '').downcase,
      origins: dist.origins.items.collect { |hash| self.origin_to_hash(hash) },
      tags: self.tags_to_hash(tags),
    }
  end

  def self.origin_to_hash(origin)
    type = if origin['custom_origin_config'] then
      'custom'
    elsif origin['s3_origin_config'] then
      's3'
    else
      fail 'Unknown origin type returned from AWS API'
    end

    hash = {
      'id' => origin[:id],
      'type' => type,
      'domain_name' => origin[:domain_name],
      'path' => origin[:origin_path],
    }

    case type
    when 'custom'
      hash['http_port'] = origin['custom_origin_config']['http_port']
      hash['https_port'] = origin['custom_origin_config']['https_port']
      hash['protocol_policy'] = origin['custom_origin_config']['origin_protocol_policy']
      hash['protocols'] = origin['custom_origin_config']['origin_ssl_protocols']['items']
    when 's3'
      Puppet.warning('CloudFront S3 origins are not supported.')
    end

    hash
  end

  # CloudFront tags are a unique data type.
  def self.name_from_cloudfront_tags(tags)
    name_tag = tags.find { |tag| tag.key.downcase == 'name' }
    name_tag ? name_tag.value : nil
  end

  def self.tags_to_hash(tags)
    tags_hash = {}
    tags.each do |tag|
      tags_hash[tag.key] = tag.value unless tag.key.downcase == 'name'
    end

    tags_hash
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    create_resp = cloudfront_client.create_distribution_with_tags({
      distribution_config_with_tags: {
        distribution_config: hash_to_distribution_config(resource),
        tags: {
          items: tags_for_resource
        },
      },
    })

    @property_hash[:ensure]       = :present
    @property_hash[:arn]          = create_resp.distribution.arn
    @property_hash[:id]           = create_resp.distribution.id
    @property_hash[:status]       = create_resp.distribution.status
    @property_hash[:just_created] = true
  end

  def hash_to_distribution_config(hash)
    dist_origins = hash['origins'].collect { |origin| hash_to_origin(origin) }

    {
      enabled: hash['enabled'],
      caller_reference: hash['name'],
      comment: (hash['comment'] or ''),
      price_class: ("PriceClass_#{hash['price_class'].capitalize}"),
      origins: {
        quantity: dist_origins.length,
        items: dist_origins,
      },
      # All values below are hard-coded defaults for now.
      default_cache_behavior: {
        target_origin_id: dist_origins[0][:id],
        min_ttl: 1,
        viewer_protocol_policy: 'allow-all',
        allowed_methods: {
          quantity: 2,
          items: ['GET', 'HEAD'],
          cached_methods: {
            quantity: 2,
            items: ['GET', 'HEAD'],
          },
        },
        forwarded_values: {
          query_string: false,
          cookies: {
            forward: 'none',
            whitelisted_names: {
              quantity: 0,
            },
          },
          headers: {
            quantity: 0,
          },
          query_string_cache_keys: {
            quantity: 0,
          },
        },
        lambda_function_associations: {
          quantity: 0,
        },
        trusted_signers: {
          enabled: false,
          quantity: 0,
        },
      },
    }
  end

  def hash_to_origin(hash)
    {
      id: hash['id'],
      domain_name: hash['domain_name'],
      custom_origin_config: {
        http_port: hash['http_port'],
        https_port: hash['https_port'],
        origin_protocol_policy: hash['protocol_policy'],
        origin_ssl_protocols: {
          quantity: hash['protocols'].length,
          items: hash['protocols'],
        },
      },
    }
  end

  def destroy
    # Disabling the distribution returns a new etag. Otherwise, get the current one.
    if enabled then etag = disable end
    etag = etag ? etag : cloudfront_client.get_distribution({id: @property_hash[:id]}).etag

    begin
      cloudfront_client.delete_distribution({
        id: @property_hash[:id],
        if_match: etag,
      })

      @property_hash[:ensure] = :absent
    rescue Aws::CloudFront::Errors::DistributionNotDisabled
      Puppet.warning("The CloudFront distribution #{@property_hash[:name]} is not finished being disabled and cannot be deleted yet.")
    end
  end

  def enabled?
    @property_hash[:enabled] == true
  end

  def enable
    enable_or_disable(:enable)
  end

  def disable
    enable_or_disable(:disable)
  end

  def enable_or_disable(which)
    to_enable = case which
    when :enable; true
    when :disable; false
    else
      fail "'#{which}' is neither :enable nor :disable"
    end

    dist_resp = cloudfront_client.get_distribution({id: @property_hash[:id]})
    dist_resp.distribution.distribution_config.enabled = to_enable
    dist_disabled_resp = cloudfront_client.update_distribution({
      id: @property_hash[:id],
      if_match: dist_resp.etag,
      distribution_config: dist_resp.distribution.distribution_config,
    })

    @property_hash[:enabled] = to_enable

    dist_disabled_resp.etag
  end

  def flush
    if @property_hash[:ensure] != :present then return end
    if @property_hash[:just_created] then return end

    Puppet.warning('Altering a CloudFront distribution is not supported yet.')
  end

end
