# a simple data structure defining a type and number of instances. Hardcoded as
# an example but this could obviously come from hiera. Change the numbers or add
# new types at will.
#
# Note that this example requires the future parser

$instances = {
  'web' => 4,
  'db'  => 2,
}


# Everything below here is really just implementation. If you like your defined
# types to employ recursion and you enjoy iteration in the future parser
# continue onwards

Ec2_instance {
  region            => 'sa-east-1',
  availability_zone => 'sa-east-1a',
}

# A recursively defined function, hurray!
define create_ec2_instances($type, $count) {
  ec2_instance { "${type}-${count}":
    ensure          => present,
    image_id        => 'ami-67a60d7a',
    security_groups => ["${type}-sg"],
    instance_type   => 't1.micro',
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

# temporarily comment lambda code requiring future parser
# each($instances) |$type, $count| {
#   create_ec2_instances { "creating-${type}-${counter}":
#     type  => $type,
#     count => $count
#   }
# }

