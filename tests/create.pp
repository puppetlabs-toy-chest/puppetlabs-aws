# This will create a set of instances, load balancers and security groups in the
# specified AWS region.

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

ec2_instance { ['web-1', 'web-2']:
  ensure          => present,
  image_id        => 'ami-41e85d5c', # SA 'ami-67a60d7a', # EU 'ami-b8c41ccf',
  security_groups => ['web-sg'],
  instance_type   => 't1.micro',
  tags            => {
    department => 'engineering',
    project    => 'cloud',
    created_by => $::id,
  }
}

ec2_instance { 'db-1':
  ensure          => present,
  image_id        => 'ami-41e85d5c', # SA 'ami-67a60d7a', # EU 'ami-b8c41ccf',
  security_groups => ['db-sg'],
  instance_type   => 't1.micro',
  monitoring      => true,
  key_name        => 'garethr-test',
  tags            => {
    department => 'engineering',
    project    => 'cloud',
    created_by => $::id,
  }
}

elb_loadbalancer { 'lb-1':
  ensure             => present,
  availability_zones => ['sa-east-1a'],
  instances          => ['web-1', 'web-2'],
  listeners          => [{
    protocol => 'tcp',
    port     => 80,
  }],
}

rds_instance { 'db-name-5':
  ensure => present,
  region => 'us-west-1',
  db_name =>  'mysqldbname3',
  engine => 'mysql',
  engine_version => '5.6.19a',
  license_model => 'general-public-license',
  allocated_storage => 10,
  availability_zone_name => 'us-west-1a',
  storage_type => 'gp2',
  db_instance_class => 'db.m3.medium',
  master_username => 'awsusername',
  master_user_password => 'the-master-password',
  multi_az => false,
}
