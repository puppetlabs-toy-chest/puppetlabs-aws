require 'aws-sdk-core'
require 'mustache'

class PuppetManifest < Mustache
  def initialize(file, config)
    @template_file = File.join(Dir.getwd, 'spec', 'acceptance', 'fixtures', file)
    config.each do |key, value|
      instance_variable_set("@#{key}".to_sym, value)
      self.class.send(:attr_accessor, key)
    end
  end
  def apply
    manifest = self.render.gsub("\n", '')
    system("bundle exec puppet apply -e \"#{manifest}\" --modulepath ../")
  end
end

class Ec2Helper

  def initialize(region)
    @client = ::Aws::EC2::Client.new({region: region})
  end

  def get_instances(name)
    response = @client.describe_instances(filters: [
      {name: 'tag:Name', values: [name]},
    ])
    response.data.reservations.collect do |reservation|
      reservation.instances.collect do |instance|
        instance
      end
    end.flatten
  end

end
