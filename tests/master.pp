# This will create a set of instances, load balancers and security groups in
# the specified AWS region.

Ec2_securitygroup {
  region => hiera('region'),
}

Ec2_instance {
  region => hiera('region'),
  availability_zone => hiera('availability_zone'),
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
  image_id        => hiera('ami'), # SA 'ami-67a60d7a', # EU 'ami-b8c41ccf',
  security_groups => ['puppet-sg'],
  user_data       => template('puppetlabs-aws/master-userdata.sh.erb'),
  instance_type   => 'c1.medium',
  tags            => {
    department => 'engineering',
    project    => 'cloud',
    created_by => 'garethr'
  }
}
