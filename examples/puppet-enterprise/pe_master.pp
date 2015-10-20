$pe_version_string = '2015.2.2'
$pe_username = 'admin'
$pe_password = 'puppetlabs'

ec2_securitygroup { 'puppet':
  ensure           => present,
  region           => 'us-west-2',
  description      => 'Group for testing puppet AWS module',
  ingress          => [{
    security_group => 'puppet',
  },{
    protocol => 'tcp',
    port     => 443,
    cidr     => '0.0.0.0/0',
  }]
}

ec2_instance { 'puppet-master':
  ensure          => present,
  region          => 'us-west-2',
  image_id        => 'ami-e08efbd0',
  instance_type   => 'm3.large',
  monitoring      => 'true',
  security_groups => ['puppet'],
  user_data       => template('master-pe-userdata.erb'),
}
