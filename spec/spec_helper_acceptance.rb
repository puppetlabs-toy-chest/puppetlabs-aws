require 'beaker-rspec'

unless ENV["BEAKER_provision"] == "no"
  hosts.each do |host|
    install_puppet
    on host, puppet('resource', 'package', 'aws-sdk-core', 'ensure=installed', 'provider=gem'), { :acceptable_exit_codes => [0,1] }
  end
  scp_to hosts, "#{ENV['HOME']}/.aws/credentials", '/root/.aws/credentials'
end

RSpec.configure do |c|
  # Project root
  proj_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))

  # Readable test descriptions
  c.formatter = :documentation

  # Configure all nodes in nodeset
  c.before :suite do
    # Install module and dependencies
    puppet_module_install(:source => proj_root, :module_name => 'aws')
  end
end
