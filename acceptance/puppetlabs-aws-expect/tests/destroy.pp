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

ec2_instance { 'test-1':
  ensure => absent,
}

ec2_securitygroup { 'test-sg':
  ensure => absent,
}

elb_loadbalancer { ['test-lb']:
  ensure => absent,
}

elb_loadbalancer { ['empty-lb']:
  ensure => absent,
}
