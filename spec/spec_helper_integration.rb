require 'beaker-rspec'

unless ENV['BEAKER_provision'] == 'no'
  # Could be toggled between PE and Puppet
  master_name = 'puppet'
  on master, "echo '10.255.33.135   #{master_name}' >> /etc/hosts"
  on master, "hostname #{master_name}"
  install_package master, 'ruby'
  on master, 'gem install aws-sdk-core'
  install_package master, 'puppetmaster'
  on master, 'puppet agent --enable'
  home = ENV['HOME']
  file = File.open("#{home}/.aws/credentials")
  agent_home = on(master, 'printenv HOME').stdout.chomp
  on(master, "mkdir #{agent_home}/.aws")
  create_remote_file(master, "#{agent_home}/.aws/credentials", file.read)
end

RSpec.configure do |c|

  c.before :suite do
    # Install from local code, could be toggled between local and package
    proj_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))
    puppet_module_install(:source => proj_root, :module_name => 'aws')
  end

end
