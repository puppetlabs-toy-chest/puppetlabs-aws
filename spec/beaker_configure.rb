require 'beaker-rspec'

install_pe

RSpec.configure do |c|

  c.before :suite do
    # find the agent that is the provisioner
    @provisioner = find_only_one(:provisioner)
    #read the AWS credential from Jenkins slave
    home = ENV['HOME']
    file = File.open("#{home}/.aws/credentials")
    # configure the agent
    agent_home = on(@provisioner, 'printenv HOME').stdout.chomp
    on(@provisioner, puppet("module install puppetlabs-pe_gem"))
    pp =<<-EOS
    package{'aws-sdk-core':
      ensure    => present,
      provider  => pe_gem,
    }
    EOS
    apply_manifest_on(@provisioner, pp)
    on(@provisioner, "mkdir #{agent_home}/.aws")
    create_remote_file(@provisioner, "#{agent_home}/.aws/credentials", file.read)
    # configure the master
    on(master, '/opt/puppet/bin/puppetserver gem install aws-sdk-core')
    # restart puppet server
    on(master, "puppet resource service pe-puppetserver ensure=stopped")
    on(master, "puppet resource service pe-puppetserver ensure=running")
    masterHostName = on(master, "hostname").stdout.chomp
    i = 0
    # -k to ignore HTTPS error that isn't relevant to us
    curl_call = "-I -k https://#{masterHostName}:8140/production/certificate_statuses/all"
    while i < 35 do
      sleep 5
      i += 1
      exit_code = curl_on(master, curl_call, :acceptable_exit_codes => [0,1,7]).exit_code
      # Exit code 7 is "connection refused"
      if exit_code != '7'
        sleep 20
        puts 'Restarting the Puppet Server was successful!'
        break
      end
    end

  end

end
