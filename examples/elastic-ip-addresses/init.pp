ec2_elastic_ip { '177.71.189.57':
  ensure   => 'attached',
  region   => 'sa-east-1',
  instance => 'web-1',
}

ec2_instance { ['web-1', 'web-2']:
  ensure        => present,
  region        => 'sa-east-1',
  image_id      => 'ami-67a60d7a',
  instance_type => 't1.micro',
}
