node 'arbiter' {
  Ec2_instance {
    image_id => hiera('default_image_id'),
    instance_type   => hiera('default_instance_type'),
    region  => hiera('default_region'),
  }
  $instances = hiera_hash('instances', {})
  create_resources(ec2_instance, $instances)
}
