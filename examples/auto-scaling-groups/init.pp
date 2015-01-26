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

ec2_scalingpolicy { 'scaleout':
  ensure             => present,
  auto_scaling_group => 'test-asg',
  scaling_adjustment => 30,
  adjustment_type    => 'PercentChangeInCapacity',
  region             => 'sa-east-1',
}

ec2_scalingpolicy { 'scalein':
  ensure             => present,
  auto_scaling_group => 'test-asg',
  scaling_adjustment => -2,
  adjustment_type    => 'ChangeInCapacity',
  region             => 'sa-east-1',
}

cloudwatch_alarm { 'AddCapacity':
  ensure              => present,
  metric              => 'CPUUtilization',
  namespace           => 'AWS/EC2',
  statistic           => 'Average',
  period              => 120,
  threshold           => 70,
  comparison_operator => 'GreaterThanOrEqualToThreshold',
  dimensions          => [{
    'AutoScalingGroupName' => 'test-asg',
  }],
  evaluation_periods  => 2,
  alarm_actions       => ['scaleout'],
  region              => 'sa-east-1',
}

cloudwatch_alarm { 'RemoveCapacity':
  ensure              => present,
  metric              => 'CPUUtilization',
  namespace           => 'AWS/EC2',
  statistic           => 'Average',
  period              => 120,
  threshold           => 40,
  comparison_operator => 'LessThanOrEqualToThreshold',
  dimensions          => [{
    'AutoScalingGroupName' => 'test-asg',
  }],
  evaluation_periods  => 2,
  region              => 'sa-east-1',
  alarm_actions       => ['scalein'],
}

