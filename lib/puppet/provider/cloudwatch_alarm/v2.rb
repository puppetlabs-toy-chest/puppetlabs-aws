require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:cloudwatch_alarm).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    regions.collect do |region|
      alarms = []
      cloudwatch_client(region).describe_alarms.each do |response|
        response.data.metric_alarms.each do |alarm|
          hash = alarm_to_hash(region, alarm)
          alarms << new(hash)
        end
      end
      alarms
    end.flatten
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region
      end
    end
  end

  read_only(:region, :alarm_actions)

  def self.alarm_to_hash(region, alarm)
    {
      name: alarm.alarm_name,
      metric: alarm.metric_name,
      namespace: alarm.namespace,
      statistic: alarm.statistic,
      period: alarm.period,
      threshold: alarm.threshold,
      evaluation_periods: alarm.evaluation_periods,
      comparison_operator: alarm.comparison_operator,
      ensure: :present,
      region: region,
      dimensions: alarm.dimensions.collect { |v| { v.name => v.value} }
    }
  end

  def exists?
    dest_region = resource[:region] if resource
    Puppet.info("Checking if alarm #{name} exists in region #{dest_region || region}")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating alarm #{name} in region #{resource[:region]}")
    update
    @property_hash[:ensure] = :present
  end

  def update
    config = {
      alarm_name: name,
      metric_name: resource[:metric],
      namespace: resource[:namespace],
      statistic: resource[:statistic],
      period: resource[:period],
      threshold: resource[:threshold],
      evaluation_periods: resource[:evaluation_periods],
      comparison_operator: resource[:comparison_operator],
    }
    if resource[:dimensions]
      dimensions = []
      resource[:dimensions].each do |dimension|
        dimensions << dimension.map { |k,v| {name: k, value: v} }
      end
      config[:dimensions] = dimensions.flatten
    end

    actions = []
    alarm_actions = resource[:alarm_actions]
    alarm_actions = [alarm_actions] unless alarm_actions.is_a?(Array)
    alarm_actions.reject(&:nil?).each do |action|
      response = autoscaling_client(resource[:region]).describe_policies(
        policy_names: [action]
      )
      actions << response.data.scaling_policies.first.policy_arn
    end
    config[:alarm_actions] = actions

    cloudwatch_client(resource[:region]).put_metric_alarm(config)
  end

  def flush
    update unless @property_hash[:ensure] == :absent
  end

  def destroy
    Puppet.info("Deleting alarm #{name} in region #{resource[:region]}")
    cloudwatch_client(resource[:region]).delete_alarms(
      alarm_names: [name],
    )
    @property_hash[:ensure] = :absent
  end
end

