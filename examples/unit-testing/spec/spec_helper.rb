require 'rspec-puppet'

root_path = File.expand_path(File.join(__FILE__, '..', '..'))

RSpec.configure do |c|
  c.module_path = File.join(root_path, 'modules')
  c.manifest_dir = File.join(root_path, 'manifests')
  c.hiera_config = 'spec/fixtures/hiera/hiera.yaml'
end
