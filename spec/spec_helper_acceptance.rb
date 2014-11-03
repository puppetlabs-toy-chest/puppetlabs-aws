require 'aws-sdk-core'
require 'mustache'

class PuppetManifest < Mustache
  def initialize(file, config)
    @template_file = File.join(Dir.getwd, 'spec', 'acceptance', 'fixtures', file)
    config.each do |key, value|
      config_value = value
      if (value.class == Hash)
        config_value = value.map { |k, v| { :k => k, :v => v }}
      end
      instance_variable_set("@#{key}".to_sym, config_value)
      self.class.send(:attr_accessor, key)
    end
  end
  def apply
    manifest = self.render.gsub("\n", '')
    system("bundle exec puppet apply -e \"#{manifest}\" --modulepath ../")
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

class AWSHelper

  def initialize(region)
    @ec2_client = ::Aws::EC2::Client.new({region: region})
    @elb_client = ::Aws::ElasticLoadBalancing::Client.new({region: region})
  end

  def get_instance(name)
    response = @ec2_client.describe_instances(filters: [
      {name: 'tag:Name', values: [name]},
    ])
    response.data.reservations.collect do |reservation|
      reservation.instances.collect do |instance|
        instance
      end
    end.flatten.first
  end

  def get_group(name)
    response = @ec2_client.describe_security_groups(
      group_names: [name]
    )
    response.data.security_groups.first
  end

  def get_loadbalancer(name)
    response = @elb_client.describe_load_balancers(
      load_balancer_names: [name]
    )
    response.data.load_balancer_descriptions.first
  end

  def tag_difference(item, tags)
    item_tags = {}
    item.tags.each { |s| item_tags[s.key.to_sym] = s.value if s.key != 'Name' }
    tags.to_set ^ item_tags.to_set
  end

end
