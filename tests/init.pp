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

Ec2_securitygroup {
  region => 'eu-west-1',
}

Ec2_instance {
  region            => 'eu-west-1',
  availability_zone => 'eu-west-1b',
}

Elb_loadbalancer {
  region => 'eu-west-1',
}

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
    security_group => 'lb-sg',
  }],
}

ec2_securitygroup { 'db-sg':
  ensure      => present,
  description => 'Security group for database servers',
  ingress     => [{
    security_group => 'web-sg',
  }],
}

ec2_instance { ['web-1', 'web-2']:
  ensure          => present,
  image_id        => 'ami-b8c41ccf',
  security_groups => ['web-sg'],
  instance_type   => 't1.micro',
}

ec2_instance { 'db':
  ensure          => present,
  image_id        => 'ami-b8c41ccf',
  security_groups => ['db-sg'],
  instance_type   => 't1.micro',
}

elb_loadbalancer { 'lb-1':
  ensure             => present,
  availability_zones => ['eu-west-1b'],
  instances          => ['web-1', 'web-2'],
  listeners          => [{
    protocol => 'tcp',
    port     => 80,
  }],
}

