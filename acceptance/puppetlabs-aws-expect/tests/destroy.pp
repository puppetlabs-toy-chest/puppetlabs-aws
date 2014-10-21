# Destroy all our test resources, created in the create.pp manifest
# Note that due to lifecyles of AWS resouces deleting security groups will
# fail until the corresponding instances have been deleted. This will be
# better modelled in the future.

Ec2_instance {
  region => 'sa-east-1',
}

Ec2_securitygroup {
  region => 'sa-east-1',
}

Elb_loadbalancer {
  region => 'sa-east-1',
}

# on Jenkins, name resources with a pretty build identifier
# otherwise, name instances via local environment info
# for the sake of preventing name collisions
$suffix = inline_template("<%= (ENV['BUILD_DISPLAY_NAME'] ||
  (ENV['USER'] + '@' + Socket.gethostname.split('.')[0])).gsub(/'/, '') %>")
# some resources have DNS rules, so simplify suffix
$dns_suffix = inline_template("<%= '${suffix}'.gsub(/[^\\dA-Za-z-]/, '') %>")

ec2_instance { "test-1-${suffix}":
  ensure => absent,
}

ec2_securitygroup { "test-sg-${suffix}":
  ensure => absent,
}

elb_loadbalancer { ["test-lb-${dns_suffix}"]:
  ensure => absent,
}

elb_loadbalancer { ["empty-lb-${dns_suffix}"]:
  ensure => absent,
}

# temporary file used to track created instances for use by acceptance tests
$filename = inline_template("<%= 'aws-resources-' +
  (ENV['BUILD_DISPLAY_NAME'] || ENV['USER']) + '.ini' %>")

file { "/tmp/${filename}":
  ensure => absent
}
