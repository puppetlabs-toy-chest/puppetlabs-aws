$pe_master_hostname = 'ip-10-23-1-24.us-west-2.compute.internal'
$pe_version_string = '3.3.2'

ec2_instance { 'tse-puppet-agent-2':
  ensure          => present,
  region          => 'us-west-2',
  image_id        => 'ami-e08efbd0',
  instance_type   => 'm3.xlarge',
  monitoring      => 'true',
  key_name        => 'chrisbarker_pl_west2',
  security_groups => ['gary_master'],
  user_data       => template('aws/el6.agent-pe-userdata.erb'),
  tags            => {
    department    => 'TSE',
    created_by    => "${::id}",
  },
}



ec2_instance { 'tse-puppet-windows-agent-2':
  ensure          => present,
  region          => 'us-west-2',
  image_id        => 'ami-21f0bc11',
  instance_type   => 'm2.xlarge',
  monitoring      => 'true',
  key_name        => 'chrisbarker_pl_west2',
  security_groups => ['gary_master'],
  user_data       => template('aws/windows-pe.erb'),
  tags            => {
    department    => 'TSE',
    created_by    => "${::id}",
  },
}
