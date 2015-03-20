ec2_vpc { 'sample-vpc':
  ensure       => present,
  region       => 'sa-east-1',
  cidr_block   => '10.0.0.0/16',
}

ec2_securitygroup { 'sample-sg':
  ensure      => present,
  region      => 'sa-east-1',
  vpc         => 'sample-vpc',
  description => 'Security group for VPC',
  ingress     => [{
    security_group => 'sample-sg',
  },{
    protocol => 'tcp',
    port     => 22,
    cidr     => '0.0.0.0/0'
  }]
}

ec2_vpc_subnet { 'sample-subnet':
  ensure            => present,
  region            => 'sa-east-1',
  vpc               => 'sample-vpc',
  cidr_block        => '10.0.0.0/24',
  availability_zone => 'sa-east-1a',
  route_table       => 'sample-routes',
}

ec2_vpc_internet_gateway { 'sample-igw':
  ensure => present,
  region => 'sa-east-1',
  vpc    => 'sample-vpc',
}

ec2_vpc_routetable { 'sample-routes':
  ensure => present,
  region => 'sa-east-1',
  vpc    => 'sample-vpc',
  routes => [
    {
      destination_cidr_block => '10.0.0.0/16',
      gateway                => 'local'
    },{
      destination_cidr_block => '0.0.0.0/0',
      gateway                => 'sample-igw'
    },
  ],
}
