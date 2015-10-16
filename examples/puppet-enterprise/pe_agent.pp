$pe_master_hostname   = 'ip-your-ip-here.us-west-2.compute.internal'
$pe_version_string    = '2015.2.2'
$agent_version_string = '1.2.6'

ec2_instance { 'puppet-agent':
  ensure          => present,
  region          => 'us-west-2',
  image_id        => 'ami-e08efbd0', # RHEL 6.5
  instance_type   => 'm3.medium',
  monitoring      => 'true',
  security_groups => ['puppet'],
  user_data       => template('agent-pe-userdata.erb'),
}

ec2_instance { 'puppet-windows-agent':
  ensure          => present,
  region          => 'us-west-2',
  image_id        => 'ami-21f0bc11', # Windows Server 2012
  instance_type   => 'm3.medium',
  monitoring      => 'true',
  security_groups => ['puppet'],
  user_data       => template('windows-pe.erb'),
}
