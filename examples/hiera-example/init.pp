# This will create a single instance based on data from hiera

ec2_securitygroup { 'hiera-test':
  ensure      => present,
  region      => hiera('region'),
  description => 'Group used for testing Puppet AWS module',
}

ec2_instance { 'hiera-1':
  ensure            => present,
  region            => hiera('region'),
  availability_zone => hiera('availability_zone'),
  image_id          => hiera('ami'),
  instance_type     => 't1.micro',
  security_groups    => ['hiera-test'],
}
