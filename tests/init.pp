# The baseline for module testing used by Puppet Labs is that each manifest
# should have a corresponding test manifest that declares that class or defined
# type.
#
# Tests are then run by using puppet apply --noop (to check for compilation
# errors and view a log of events) or by fully applying the test in a virtual
# environment (to compare the resulting system state to the desired state).
#
# Learn more about module testing here:
# http://docs.puppetlabs.com/guides/tests_smoke.html
#

ec2_securitygroup { 'lb-sg':
  ensure      => present,
  description => 'Security group for load balancer',
  ingress     => [{
    protocol => 'tcp',
    port     => 80,
    cidr     => '0.0.0.0/0'
  }],
}

ec2_securitygroup { 'web-sg':
  ensure      => present,
  description => 'Security group for web servers',
  ingress     => [{
    source => Ec2_securitygroup['lb-sg'],
  }],
}

ec2_securitygroup { 'db-sg':
  ensure      => present,
  description => 'Security group for database servers',
  ingress     => [{
    source => Ec2_securitygroup['web-sg'],
  }],
}

ec2_instance { ['web-1', 'web-2']:
  ensure          => present,
  image_id        => 'ami-2d9add1d',
  security_groups => [Ec2_securitygroup['web-sg']],
  instance_type   => 't1.micro',
}

ec2_instance { 'db':
  ensure          => present,
  image_id        => 'ami-2d9add1d',
  security_groups => [Ec2_securitygroup['db-sg']],
  instance_type   => 't1.micro',
}

elb_loadbalancer { 'lb-1':
  ensure             => present,
  security_groups    => [Ec2_securitygroup['lb-sg']],
  availability_zones => ['us-west-2a'],
  instances          => [
    Ec2_instance['web-1'],
    Ec2_instance['web-2'],
  ],
  listeners          => [{
    protocol => 'tcp',
    port     => 80,
  }],
}

