# This will create a set of instances, load balancers and security groups in the specified
# AWS region.

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
  },{
    protocol => 'tcp',
    port     => 22,
    cidr     => '0.0.0.0/0'
  }],
}

ec2_securitygroup { 'db-sg':
  ensure      => present,
  description => 'Security group for database servers',
  ingress     => [{
    security_group => 'web-sg',
  },{
    protocol => 'tcp',
    port     => 22,
    cidr     => '0.0.0.0/0'
  }],
}

ec2_securitygroup { 'puppet-sg':
  ensure      => present,
  description => 'Puppet master security group',
  ingress     => [{
    security_group => 'web-sg',
  },{
    security_group => 'db-sg',
  },{
    protocol => 'tcp',
    port     => 22,
    cidr     => '0.0.0.0/0'
  }],
}


ec2_instance { ['web-1', 'web-2']:
  ensure          => present,
  image_id        => 'ami-41e85d5c', # SA 'ami-67a60d7a', # EU 'ami-b8c41ccf',
  security_groups => ['web-sg'],
  user_data       => file('puppetlabs-aws/agent-userdata.sh'),
  instance_type   => 't1.micro',
  tags            => {
    department => 'engineering',
    project    => 'cloud',
    created_by => 'garethr'
  }
}

ec2_instance { 'db-1':
  ensure          => present,
  image_id        => 'ami-41e85d5c', # SA 'ami-67a60d7a', # EU 'ami-b8c41ccf',
  security_groups => ['db-sg'],
  user_data       => file('puppetlabs-aws/agent-userdata.sh'),
  instance_type   => 't1.micro',
  tags            => {
    department => 'engineering',
    project    => 'cloud',
    created_by => 'garethr'
  }
}

#ec2_instance { 'puppet-1':
#  ensure          => present,
#  image_id        => 'ami-41e85d5c', # SA 'ami-67a60d7a', # EU 'ami-b8c41ccf',
#  security_groups => ['puppet-sg'],
#  instance_type   => 'c1.medium',
#}

elb_loadbalancer { 'lb-1':
  ensure             => present,
  availability_zones => ['sa-east-1a'],
  instances          => ['web-1', 'web-2'],
  listeners          => [{
    protocol => 'tcp',
    port     => 80,
  }],
}
