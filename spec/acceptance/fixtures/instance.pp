ec2_instance { '{{name}}':
  ensure => {{ensure}},
  region => '{{region}}',
  image_id => '{{image_id}}',
  instance_type => '{{instance_type}}',
  security_groups => ['default'],
}
