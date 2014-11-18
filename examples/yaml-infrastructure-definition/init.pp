$instances = hiera_hash('instances', {})
$groups = hiera_hash('security_groups', {})

create_resources(ec2_securitygroup, $groups)
create_resources(ec2_instance, $instances)
