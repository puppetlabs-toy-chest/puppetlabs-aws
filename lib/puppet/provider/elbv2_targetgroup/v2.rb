require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:elbv2_targetgroup).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do

  confine feature: :aws

  mk_resource_methods

  def self.instances()
    Puppet.debug('Fetching ELBv2 Target Groups (instances)')
    regions.collect do |region|
    Puppet.debug("instances region: #{region}")
      target_groups = []
      tgs(region) do |tg|
        target_groups << new(target_group_to_hash(region, tg) )
      end

      target_groups
    end.flatten
  end

  def self.tgs(region)
    Puppet.debug('Fetching ELBv2 Target Groups (tgs)')
#    regions.collect do |region|
      region_client = elbv2_client(region)

      response = region_client.describe_target_groups()
      marker = response.next_marker

      response.target_groups.each do |tg|
        yield tg
      end

      while marker
        Puppet.debug("Calling for marked TargetGroup description")
        response = region_client.describe_target_groups( {
          marker: marker
        })
        marker = response.next_marker
        response.target_group_descriptions.each do |tg|
          yield tg
        end
      end
#    end
  end

  def self.target_group_to_hash(region, target_group)
    Puppet.debug("target_group_to_hash for #{target_group.target_group_name}")

    attributes = { }
    response = elbv2_client(region).describe_target_group_attributes(target_group_arn: target_group.target_group_arn)
    response.attributes.collect do |attribute|
      attributes[attribute.key] = attribute.value
    end

    tag_response = elbv2_client(region).describe_tags(
      resource_arns: [ target_group.target_group_arn ]
    )
    tags = {}
    unless tag_response.tag_descriptions.nil? || tag_response.tag_descriptions.empty?
      tag_response.tag_descriptions.first.tags.each do |tag|
        tags[tag.key] = tag.value
      end
    end

    load_balancers = []

    {
      name: target_group.target_group_name,
      ensure: :present,
      region: region,
      vpc: target_group.vpc_id,
      protocol: target_group.protocol,
      port: target_group.port,
      load_balancers: load_balancers,
      healthy_threshold: target_group.healthy_threshold_count,
      unhealthy_threshold: target_group.unhealthy_threshold_count,
      health_check_path: target_group.health_check_path,
      health_check_port: target_group.health_check_port,
      health_check_protocol: target_group.health_check_protocol,
      health_check_interval: target_group.health_check_interval_seconds,
      health_check_success_codes: target_group.matcher.http_code,
      health_check_timeout: target_group.health_check_timeout_seconds,
      deregistration_delay: attributes['deregistration_delay.timeout_seconds'],
      stickiness: attributes['stickiness.enabled'],
      stickiness_duration: attributes['stickiness.lb_cookie.duration_seconds'],
      tags: tags,
    }
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating target group #{name} #{resource[:protocol]} #{resource[:port]} in region #{target_region}")
    fail('You must specify the AWS region') unless target_region != :absent
    fail('You must specify the Target protocol') if resource[:protocol].nil?
    fail('You must specify the Target port') if resource[:port].nil?

  end
end
