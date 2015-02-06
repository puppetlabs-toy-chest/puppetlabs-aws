require 'aws-sdk-core'
require 'mustache'
require 'open3'

class PuppetManifest < Mustache

  def initialize(file, config)
    @template_file = File.join(Dir.getwd, 'spec', 'acceptance', 'fixtures', file)
    config.each do |key, value|
      config_value = self.class.to_generalized_data(value)
      instance_variable_set("@#{key}".to_sym, config_value)
      self.class.send(:attr_accessor, key)
    end
  end

  def apply
    manifest = self.render.gsub("\n", '')
    cmd = "bundle exec puppet apply --detailed-exitcodes -e \"#{manifest}\" --modulepath ../"
    result = { output: [], exit_status: nil }

    Open3.popen2e(cmd) do |stdin, stdout_err, wait_thr|
      while line = stdout_err.gets
        result[:output].push(line)
        puts line
      end

      result[:exit_status] = wait_thr.value
    end

    result
  end

  def self.to_generalized_data(val)
    case val
    when Hash
      to_generalized_hash_list(val)
    when Array
      to_generalized_array_list(val)
    else
      val
    end
  end

  # returns an array of :k =>, :v => hashes given a Hash
  # { :a => 'b', :c => 'd' } -> [{:k => 'a', :v => 'b'}, {:k => 'c', :v => 'd'}]
  def self.to_generalized_hash_list(hash)
    hash.map { |k, v| { :k => k, :v => v }}
  end

  # necessary to build like [{ :values => Array }] rather than [[]] when there
  # are nested hashes, for the sake of Mustache being able to render
  # otherwise, simply return the item
  def self.to_generalized_array_list(arr)
    arr.map do |item|
      if item.class == Hash
        {
          :values => to_generalized_hash_list(item)
        }
      else
        item
      end
    end
  end

  def self.env_id
    @env_id ||= (
      ENV['BUILD_DISPLAY_NAME'] ||
      (ENV['USER'] + '@' + Socket.gethostname.split('.')[0])
    ).gsub(/'/, '')
  end

  def self.env_dns_id
    @env_dns_id ||= @env_id.gsub(/[^\\dA-Za-z-]/, '')
  end
end

class AwsHelper

  attr_reader :ec2_client, :elb_client

  def initialize(region)
    @ec2_client = ::Aws::EC2::Client.new({region: region})
    @elb_client = ::Aws::ElasticLoadBalancing::Client.new({region: region})
    @autoscaling_client = ::Aws::AutoScaling::Client.new({region: region})
    @cloudwatch_client = ::Aws::CloudWatch::Client.new({region: region})
  end

  def get_instances(name)
    response = @ec2_client.describe_instances(filters: [
      {name: 'tag:Name', values: [name]},
    ])
    response.data.reservations.collect do |reservation|
      reservation.instances.collect do |instance|
        instance
      end
    end.flatten
  end

  def get_instance(name)
    instances = self.get_instances(name)
    if instances.count == 1
      instances.first
    else
      raise StandardError, 'A single instance was not returned from AWS'
    end
  end

  def get_groups(name)
    response = @ec2_client.describe_security_groups(
      group_names: [name]
    )

    response.data.security_groups
  end

  def get_group(name)
    groups = self.get_groups(name)
    if groups.count == 1
      groups.first
    else
      raise StandardError, 'A single group was not returned from AWS'
    end
  end

  def get_loadbalancers(name)
    response = @elb_client.describe_load_balancers(
      load_balancer_names: [name]
    )

    response.data.load_balancer_descriptions
  end

  def get_loadbalancer(name)
    load_balancers = self.get_loadbalancers(name)
    if load_balancers.count == 1
      load_balancers.first
    else
      raise StandardError, 'A single load balancer was not returned from AWS'
    end
  end

  def tag_difference(item, tags)
    item_tags = {}
    item.tags.each { |s| item_tags[s.key.to_sym] = s.value if s.key != 'Name' }
    tags.to_set ^ item_tags.to_set
  end

  def get_autoscaling_groups(name)
    response = @autoscaling_client.describe_auto_scaling_groups(
      auto_scaling_group_names: [name]
    )
    response.data.auto_scaling_groups
  end

  def get_launch_configs(name)
    response = @autoscaling_client.describe_launch_configurations(
      launch_configuration_names: [name]
    )
    response.data.launch_configurations
  end

  def get_scaling_policies(name, group)
    response = @autoscaling_client.describe_policies(
      auto_scaling_group_name: group,
      policy_names: [name]
    )
    response.data.scaling_policies
  end

  def get_alarms(name)
    response = @cloudwatch_client.describe_alarms(
      alarm_names: [name]
    )
    response.data.metric_alarms
  end

end
