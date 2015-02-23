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
  attr_reader :ec2_client, :elb_client, :autoscaling_client

  def initialize(region)
    @ec2_client = ::Aws::EC2::Client.new({region: region})
    @elb_client = ::Aws::ElasticLoadBalancing::Client.new({region: region})
    @autoscaling_client = ::Aws::AutoScaling::Client.new({region: region})
    @cloudwatch_client = ::Aws::CloudWatch::Client.new({region: region})
    @route53_client = ::Aws::Route53::Client.new({region: region})
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

  def get_groups(name)
    response = @ec2_client.describe_security_groups(
      group_names: [name]
    )
    response.data.security_groups
  end

  def get_vpcs(name)
    response = @ec2_client.describe_vpcs(filters: [
      {name: 'tag:Name', values: [name]},
    ])
    response.data.vpcs
  end

  def get_dhcp_options(name)
    response = @ec2_client.describe_dhcp_options(filters: [
      {name: 'tag:Name', values: [name]},
    ])
    response.data.dhcp_options
  end

  def get_route_tables(name)
    response = @ec2_client.describe_route_tables(filters: [
      {name: 'tag:Name', values: [name]},
    ])
    response.data.route_tables
  end

  def get_subnets(name)
    response = @ec2_client.describe_subnets(filters: [
      {name: 'tag:Name', values: [name]},
    ])
    response.data.subnets
  end

  def get_vpn_gateways(name)
    response = @ec2_client.describe_vpn_gateways(filters: [
      {name: 'tag:Name', values: [name]},
    ])
    response.data.vpn_gateways
  end

  def get_internet_gateways(name)
    response = @ec2_client.describe_internet_gateways(filters: [
      {name: 'tag:Name', values: [name]},
    ])
    response.data.internet_gateways
  end

  def get_customer_gateways(name)
    response = @ec2_client.describe_customer_gateways(filters: [
      {name: 'tag:Name', values: [name]},
    ])
    response.data.customer_gateways
  end

  def get_vpn(name)
    response = @ec2_client.describe_vpn_connections(filters: [
      {name: 'tag:Name', values: [name]},
    ])
    response.data.vpn_connections
  end

  def get_loadbalancers(name)
    response = @elb_client.describe_load_balancers(
      load_balancer_names: [name]
    )
    response.data.load_balancer_descriptions
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

  def get_dns_zones(name)
    @route53_client.list_hosted_zones.data.hosted_zones.select { |zone|
      zone.name == name
    }
  end

  def get_dns_records(name, zone, type)
    records = @route53_client.list_resource_record_sets(hosted_zone_id: zone.id)
    records.data.resource_record_sets.select { |r| r.type == type && r.name == name}
  end

end

# a tool for applying commands on the system that is running a test
class TestExecutor

  def self.shell(cmd)
    Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
      @out = read_stream(stdout)
      @error = read_stream(stderr)
      @code = /(exit)(\s)(\d+)/.match(wait_thr.value.to_s)[3]
    end
    TestExecutor::Response.new(@out, @error, @code, cmd)
  end

  def self.read_stream(stream)
    result = String.new
    while line = stream.gets
      result << line if line.class == String
      puts line
    end
    result
  end

  # build and apply complex puppet resource commands
  # the arguement resource is the type of the resource
  # the opts hash must include a key 'name'
  def self.puppet_resource(resource, opts = {}, command_flags = '')
    raise 'A name for the resource must be specified' unless opts[:name]
    cmd = "puppet resource #{resource} "
    options = String.new
    opts.each do |k,v|
      if k.to_s == 'name'
        @name = v
      else
        options << "#{k.to_s}=#{v.to_s} "
      end
    end
    cmd << "#{@name} "
    cmd << options
    cmd << " #{command_flags}"
    # apply the command
    response = shell(cmd)
    response
  end

end

class TestExecutor::Response
  attr_reader :stdout , :stderr, :exit_code, :command

  def initialize(standard_out, standard_error, exit, cmd)
    @stdout = standard_out
    @stderr = standard_error
    @exit_code = exit
    @command = cmd
  end

end
