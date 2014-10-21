# This will create a set of instances, load balancers and
# security groups in the specified AWS region.

Ec2_securitygroup {
  region => 'sa-east-1',
}

Ec2_instance {
  region            => 'sa-east-1',
  availability_zone => 'sa-east-1a',
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

ec2_securitygroup { "test-sg-${suffix}":
  ensure      => present,
  description => 'Security group for load balancer',
  ingress     => [{
    protocol => 'tcp',
    port     => 80,
    cidr     => '0.0.0.0/0'
  }],
}

ec2_instance { "test-1-${suffix}":
  ensure          => present,
  image_id        => 'ami-41e85d5c', # SA 'ami-67a60d7a', # EU 'ami-b8c41ccf',
  instance_type   => 't1.micro',
  security_groups => ['default'],
  tags            => {
    department => 'engineering',
    project    => 'cloud',
    created_by => 'garethr'
  }
}

elb_loadbalancer { "test-lb-${dns_suffix}":
  ensure             => present,
  availability_zones => ['sa-east-1a'],
  instances          => "test-1-${suffix}",
  listeners          => [{
    protocol => 'tcp',
    port     => 80,
  }],
}

elb_loadbalancer { "nil-lb-${dns_suffix}":
  ensure             => present,
  availability_zones => ['sa-east-1a'],
  listeners          => [{
    protocol => 'tcp',
    port     => 80,
  }],
}

# track the created resources in a /tmp INI file for use by acceptance tests
$filename = inline_template("<%= 'aws-resources-' +
  (ENV['BUILD_DISPLAY_NAME'] || ENV['USER']) + '.ini' %>")

file { "/tmp/${filename}":
  content => "[resources]
instances=test-1-${suffix}
securitygroups=test-sg-${suffix}
loadbalancers=test-lb-${dns_suffix},nil-lb-${dns_suffix}
"
}
