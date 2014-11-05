# a simple data structure defining a type and number of instances. Hardcoded as
# an example but this could obviously come from hiera or other sources.
# Change the numbers or add new types at will.
#
# Note that this example requires the future parser

$instances = {
  'web' => 4,
  'db'  => 2,
}


# Everything below here is really just implementation. If you like your defined
# types to employ recursion and you enjoy iteration in the future parser
# continue onwards

# A recursively defined function, hurray!
define create_ec2_instances($type, $count) {
  ec2_instance { "${type}-${count}":
    ensure            => present,
    region            => 'us-west-1',
    availability_zone => 'us-west-1a',
    image_id          => 'ami-696e652c', # Ubuntu 14.04 LTS EBS
    security_groups   => ["${type}-sg"],
    instance_type     => 't1.micro',
  }
  $counter = inline_template('<%= @count.to_i - 1 %>')
  if $counter == '0' {
  } else {
    create_ec2_instances { "creating-${type}-${counter}":
      type  => $type,
      count => $counter,
    }
  }
}

each($instances) |$type, $count| {
  ec2_securitygroup { "${type}-sg":
    ensure            => present,
    description       => "Security group for ${type} instances",
    region            => 'us-west-1',
    ingress           => [{
      security_group  => "${type}-sg"
    },{
      protocol => 'tcp',
      port     => 22,
      cidr     => '0.0.0.0/0',
    }]
  }
  create_ec2_instances { "creating-${type}-${counter}":
    type  => $type,
    count => $count
  }
}

