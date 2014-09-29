# This will create a set of instances, load balancers and security groups in
# the specified AWS region.

Ec2_securitygroup {
  region => 'sa-east-1',
}

Ec2_instance {
  region            => 'sa-east-1',
  availability_zone => 'sa-east-1a',
}

ec2_securitygroup { 'puppet-sg':
  ensure      => present,
  description => 'Puppet master security group',
  ingress     => [{
    security_group => 'web-sg',
  },{
    security_group => 'db-sg',
  },{
    protocol => 'tcp',
    port     => 22,
    cidr     => '0.0.0.0/0'
  }],
}

ec2_instance { 'puppet-1':
  ensure          => present,
  image_id        => 'ami-41e85d5c', # SA 'ami-67a60d7a', # EU 'ami-b8c41ccf',
  security_groups => ['puppet-sg'],
  user_data       => file('puppetlabs-aws/master-userdata.sh'),
  instance_type   => 'c1.medium',
  tags            => {
    department => 'engineering',
    project    => 'cloud',
    created_by => 'garethr'
  }
}
