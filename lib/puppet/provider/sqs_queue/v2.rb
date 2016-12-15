require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:sqs_queue).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    queue_array = []
    regions.collect do |region|
      sqs = sqs_client(region)
      sqs.list_queues().data.queue_urls.each() do |queue_url|
        attrs = sqs.get_queue_attributes(:queue_url => queue_url, :attribute_names => ['All'])
        queue_array << new(queue_to_hash(queue_url.split('/')[-1], region, queue_url, attrs.data[:attributes]))
      end
    end
    queue_array
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region
        resource[:url] = prov.url
      end
    end
  end

  def create
    sqs = sqs_client(target_region)

    attributes = get_queue_api_attributes(@resource)
    url = sqs.create_queue(
      {
          queue_name: name,
          attributes: attributes
      }
    )
    @property_hash[:ensure] = :present
    @property_hash[:url] = url.data[:queue_url]
  end

  def destroy
    sqs = sqs_client(target_region)
    Puppet.notice("Destroying queue #{resource[:url]}")
    response = sqs.delete_queue(
      {
          queue_url: @resource[:url]
      }
    )

    @property_hash[:ensure] = :absent
    if response.error
      fail("Failed to delete queue: #{response.error}") if response.error
    end
    response.error
  end

  def exists?
    Puppet.debug("Checking if queue is present")
    @property_hash[:ensure] == :present
  end


  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  def delay_seconds=(value)
    @property_flush[:delay_seconds] = value
  end

  def message_retention_period=(value)
    @property_flush[:message_retention_period] = value
  end

  def visibility_timeout=(value)
    @property_flush[:visibility_timeout=] = value
  end

  def maximum_message_size=(value)
    @property_flush[:maximum_message_size] = value
  end

  def get_name
    return @property_hash[:name]
  end


  def get_queue_api_attributes (attrs)
    transformations = {:delay_seconds => :DelaySeconds, :message_retention_period => :MessageRetentionPeriod,
                       :maximum_message_size => :MaximumMessageSize, :visibility_timeout => :VisibilityTimeout}
    new_hash = {}
    transformations.map do |k, v|
      new_hash[v] = attrs[k]
    end
    new_hash
  end


  def flush
    unless (@property_hash[:ensure] == :absent || @property_hash[:ensure] == :purged)

      attributes = get_queue_api_attributes(@resource)
      sqs_client(target_region).set_queue_attributes(
        {
            queue_url: @property_hash[:url],
            attributes: attributes
        }
      )
      @property_hash = resource.to_hash
    end
  end

  def self.queue_to_hash (queue_name, region, queue_url, attrs)
    queue_hash = {
        name: queue_name,
        region: region,
        ensure: :present,
        url: queue_url,
        delay_seconds: attrs['DelaySeconds'],
        message_retention_period: attrs['MessageRetentionPeriod'],
        visibility_timeout: attrs['VisibilityTimeout'],
        maximum_message_size: attrs['MaximumMessageSize'],
    }
  end
end
