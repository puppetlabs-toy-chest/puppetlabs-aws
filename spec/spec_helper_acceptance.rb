require 'aws-sdk-core'
require 'mustache'
require 'open3'

if ENV['PUPPET_AWS_USE_BEAKER'] and ENV['PUPPET_AWS_USE_BEAKER'] == 'yes'
  require 'beaker-rspec'
  require 'beaker/puppet_install_helper'
  unless ENV['BEAKER_provision'] == 'no'
    install_pe

    proj_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))
    puppet_module_install(:source => proj_root, :module_name => 'aws')

    on(default, puppet('resource package aws-sdk-core ensure=installed provider=puppet_gem'))
    on(default, puppet('resource package retries ensure=installed provider=puppet_gem'))

    # install aws creds on SUT
    home = ENV['HOME']
    file = File.open("#{home}/.aws/credentials")
    agent_home = on(default, 'printenv HOME').stdout.chomp
    on(default, "mkdir #{agent_home}/.aws")
    create_remote_file(default, "#{agent_home}/.aws/credentials", file.read)
    # TODO enable promotion of artifact to modules forge
  end
end

class PuppetManifest < Mustache

  attr_accessor :optional_tags, :optional_load_balancers

  def initialize(file, config)
    @template_file = File.join(Dir.getwd, 'spec', 'acceptance', 'fixtures', file)
    @optional_tags = config[:tags].is_a?(Hash) and !config[:tags].empty?
    @optional_load_balancers = config[:load_balancers].is_a?(Array) and !config[:load_balancers].empty?
    config.each do |key, value|
      config_value = self.class.to_generalized_data(value)
      instance_variable_set("@#{key}".to_sym, config_value)
      self.class.send(:attr_accessor, key)
    end
  end

  def apply
    PuppetRunProxy.new.apply(self.render)
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

  def self.rds_id
    @rds_id ||= (
      ENV['BUILD_DISPLAY_NAME'] ||
      (ENV['USER'])
    ).gsub(/\W+/, '')
  end

  def self.env_dns_id
    @env_dns_id ||= @env_id.gsub(/[^\\dA-Za-z-]/, '')
  end
end

class AwsHelper
  attr_reader :ec2_client, :elb_client, :autoscaling_client

  def initialize(region)
    ENV['AWS_REGION'] = region
    @ec2_client = ::Aws::EC2::Client.new({region: region})
    @elb_client = ::Aws::ElasticLoadBalancing::Client.new({region: region})
    @autoscaling_client = ::Aws::AutoScaling::Client.new({region: region})
    @cloudwatch_client = ::Aws::CloudWatch::Client.new({region: region})
    @route53_client = ::Aws::Route53::Client.new({region: region})
    @rds_client = ::Aws::RDS::Client.new({region: region})
    @sqs_client = ::Aws::SQS::Client.new({region: region})
    @iam_client = ::Aws::IAM::Client.new({region: region})
  end


  def get_sqs_queue_url(name)
    response = @sqs_client.get_queue_url(
      queue_name: name
    )
    response.data.queue_url
  end

  def get_sqs_queue_attributes(url)
    response = @sqs_client.get_queue_attributes(
      queue_url: url,
      attribute_names: ['All']
    )
    response.data.attributes
  end


  def get_rds_instance(name)
    response = @rds_client.describe_db_instances(
      db_instance_identifier: name
    )
    response.data.db_instances
  end

  def get_db_security_groups(name)
    response = @rds_client.describe_db_security_groups(
      db_security_group_name: name
    )
    response.data.db_security_groups
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

  def vpc_only?
    response = @ec2_client.describe_account_attributes(
      attribute_names: ['supported-platforms']
    )
    response.data.account_attributes.first.attribute_values.size == 1
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

  def get_iam_users(name)
    @iam_client.list_users.users.select { |user| user.user_name == name }
  end

  def get_iam_roles(name)
    @iam_client.list_roles.roles.select { |role| role.role_name == name }
  end

  def get_iam_instance_profiles(name)
    @iam_client.list_instance_profiles.instance_profiles.select { |instance_profile|
      instance_profile.instance_profile_name == name
    }
  end

  def get_iam_instance_profiles_for_role(name)
    response = @iam_client.list_instance_profiles_for_role(
        role_name: [name]
    )
    response.data.instance_profiles
  end
end

class TestExecutor
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
    cmd << " --libdir lib #{command_flags}"
    # apply the command
    response = PuppetRunProxy.new.resource(cmd)
    response
  end

end

class PuppetRunProxy
  attr_accessor :mode

  def initialize
    @mode = if ENV['PUPPET_AWS_USE_BEAKER'] and ENV['PUPPET_AWS_USE_BEAKER'] == 'yes'
      :beaker
    else
      :local
    end
  end

  def apply(manifest)
    case @mode
    when :local
      cmd = "bundle exec puppet apply --detailed-exitcodes -e \"#{manifest.gsub("\n", '')}\" --modulepath spec/fixtures/modules/ --libdir lib --debug --trace"
      use_local_shell(cmd)
    else
      # acceptable_exit_codes and expect_changes are passed because we want detailed-exit-codes but want to
      # make our own assertions about the responses
      apply_manifest(manifest, {:acceptable_exit_codes => (0...256), :expect_changes => true, :debug => true,})
    end
  end

  def resource(cmd)
    case @mode
    when :local
      # local commands use bundler to isolate the  puppet environment
      cmd.prepend('bundle exec ')
      use_local_shell(cmd)
    else
      # beaker has a puppet helper to run puppet on the remote system so we remove the explicit puppet part of the command
      cmd = "#{cmd.split('puppet ').join}"
      # when running under beaker we install the module via the package, so need to use the default module path
      cmd ="#{cmd.split(/--modulepath \S*/).join}"
      on(default, puppet(cmd))
    end
  end

  private
  def use_local_shell(cmd)
    Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
      @out = read_stream(stdout)
      @error = read_stream(stderr)
      @code = /(exit)(\s)(\d+)/.match(wait_thr.value.to_s)[3]
    end
    BeakerLikeResponse.new(@out, @error, @code, cmd)
  end

  def read_stream(stream)
    result = String.new
    while line = stream.gets
      result << line if line.class == String
      puts line
    end
    result
  end

end

class BeakerLikeResponse
  attr_reader :stdout , :stderr, :exit_code, :command

  def initialize(standard_out, standard_error, exit, cmd)
    @stdout = standard_out
    @stderr = standard_error
    @exit_code = exit.to_i
    @command = cmd
  end

end
