# This will create a set of instances, load balancers and
# security groups in the specified AWS region.

Ec2_securitygroup {
  region => 'sa-east-1',
}

Ec2_instance {
  region            => 'sa-east-1',
  availability_zone => 'sa-east-1a',
}

Elb_loadbalancer {
  region => 'sa-east-1',
}

ec2_securitygroup { 'test-sg':
  ensure      => present,
  description => 'Security group for load balancer',
  ingress     => [{
    protocol => 'tcp',
    port     => 80,
    cidr     => '0.0.0.0/0'
  }],
}

ec2_instance { 'test-1':
  ensure          => present,
  image_id        => 'ami-41e85d5c', # SA 'ami-67a60d7a', # EU 'ami-b8c41ccf',
  instance_type   => 't1.micro',
  security_groups => ['default'],
  tags            => {
    department => 'engineering',
    project    => 'cloud',
    created_by => 'garethr'
  }
}

elb_loadbalancer { 'test-lb':
  ensure             => present,
  availability_zones => ['sa-east-1a'],
  instances          => 'test-1',
  listeners          => [{
    protocol => 'tcp',
    port     => 80,
  }],
}

elb_loadbalancer { 'empty-lb':
  ensure             => present,
  availability_zones => ['sa-east-1a'],
  listeners          => [{
    protocol => 'tcp',
    port     => 80,
  }],
}
