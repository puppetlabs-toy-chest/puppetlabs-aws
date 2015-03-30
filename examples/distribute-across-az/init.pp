# Feel free to change these variables to launch a different number
# of instances or launch them in different availability zones
$availability_zones = ['sa-east-1a', 'sa-east-1b']
$number_of_app_servers = "5"
$maximum_app_servers = 10
$region = 'sa-east-1'
$ami = 'ami-67a60d7a'

# Don't change below this line
# First lets validate the variables passed in
assert_type(Array[String[1]], $availability_zones)
assert_type(String[1], $region)
assert_type(String[1], $ami)
assert_type(Integer, $number_of_app_servers)
assert_type(Integer, $maximum_app_servers)

if $number_of_app_servers > $maximum_app_servers {
  fail("Required number of app servers (${number_of_app_servers}) must be smaller than the maximum (${maximum_app_servers})")
}

# We're going to be creating instances so lets set
# so sensible defaults
Ec2_instance {
  ensure        => 'running',
  image_id      => $ami,
  instance_type => 't1.micro',
  region        => $region,
}


# This section launches one instance in each of the passed
# availability zones, giving each a unique name
$availability_zones.each |$az_name| {
  $az_num = $az_name ? {
    /.*a$/  => '1',
    /.*b$/  => '2',
    /.*c$/  => '3',
    default => undef
  }
  $instance_name = "lb-${az_num}"
  ec2_instance { $instance_name:
    availability_zone => $az_name,
  }
}

# The next section distributes $number_of_app_servers of
# instances across the specified availability zones
$web_nodes = range(1, $number_of_app_servers).map |$node| {
  $zone = $node % $availability_zones.count
  [$node, $availability_zones[$zone]]
}
# This returns an array of hashes which looks like
# [{1 => 'us-west-2a'}, {2 => 'us-west-2b'}]
# For the next loop we use hash and flatten to turn into
# {1 => 'us-west-2a', 2 => 'us-west-2b'}
hash(flatten($web_nodes)).each |$node_num, $az_name| {
  $instance_name = "app-${node_num}"
  ec2_instance { $instance_name:
    availability_zone => $az_name,
  }
}

# Finally lets delete any nodes we no longer require
# this allows you to reduce the $number_of_app_servers
# variable and delete any left-over instances
range($number_of_app_servers+1, $maximum_app_servers).each |$node| {
  $instance_name = "app-${node}"
  ec2_instance { $instance_name:
    ensure => absent,
  }
}
