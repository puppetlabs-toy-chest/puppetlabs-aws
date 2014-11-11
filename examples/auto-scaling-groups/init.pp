ec2_securitygroup { 'garethr-sg-test':
  ensure      => present,
  description => 'group for testing autoscaling group',
  region      => 'sa-east-1',
}

ec2_launchconfiguration { 'garethr-lc-test':
  ensure          => present,
  security_groups => ['garethr-sg-test'],
  region          => 'sa-east-1',
  image_id        => 'ami-67a60d7a',
  instance_type   => 't1.micro',
}

ec2_autoscalinggroup { 'gareth-asg-test':
  ensure               => present,
  min_size             => 1,
  max_size             => 3,
  region               => 'sa-east-1',
  launch_configuration => 'garethr-lc-test',
  availability_zones   => ['sa-east-1a'],
}
