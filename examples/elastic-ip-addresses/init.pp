ec2_elastic_ip { '177.71.189.57':
  ensure   => 'attached',
  region   => 'sa-east-1',
  instance => 'web-1',
  instance_id => 'i-c07c4f3',
}
