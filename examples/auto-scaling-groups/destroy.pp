cloudwatch_alarm { ['AddCapacity', 'RemoveCapacity']:
  ensure => absent,
  region => 'sa-east-1',
} ~>

ec2_scalingpolicy { ['scaleout', 'scalein']:
  ensure             => absent,
  auto_scaling_group => 'test-asg',
  region             => 'sa-east-1',
} ~>

ec2_autoscalinggroup { 'test-asg':
  ensure => absent,
  region => 'sa-east-1',
} ~>

ec2_launchconfiguration { 'test-lc':
  ensure => absent,
  region => 'sa-east-1',
}
