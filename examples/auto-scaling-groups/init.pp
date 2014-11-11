ec2_securitygroup { 'test-sg':
  ensure      => present,
  description => 'group for testing autoscaling group',
  region      => 'sa-east-1',
}

ec2_launchconfiguration { 'test-lc':
  ensure          => present,
  security_groups => ['test-sg'],
  region          => 'sa-east-1',
  image_id        => 'ami-67a60d7a',
  instance_type   => 't1.micro',
}

ec2_autoscalinggroup { 'test-asg':
  ensure               => present,
  min_size             => 2,
  max_size             => 4,
  region               => 'sa-east-1',
  launch_configuration => 'test-lc',
  availability_zones   => ['sa-east-1b', 'sa-east-1a'],
}
