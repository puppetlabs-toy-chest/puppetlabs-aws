$pe_username = 'admin@puppetlabs.com'
$pe_password = 'puppetlabs'
$pe_version_string = '3.3.2'

ec2_instance { 'tse-puppet-master':
  ensure          => present,
  region          => 'us-west-2',
  image_id        => 'ami-e08efbd0',
  instance_type   => 'm3.xlarge',
  monitoring      => 'true',
  key_name        => 'chrisbarker_pl_west2',
  security_groups => ['gary_master'],
  user_data       => template('aws/master-pe-userdata.erb'),
  tags            => {
    department    => 'TSE',
    created_by    => "${::id}",
  },
}
