ec2_instance { ['web-1', 'web-2']:
  ensure        => present,
  region        => 'sa-east-1',
  image_id      => 'ami-67a60d7a',
  instance_type => 't1.micro',
}