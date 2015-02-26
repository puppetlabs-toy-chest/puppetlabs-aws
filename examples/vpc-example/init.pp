ec2_vpc { 'sample-vpc':
  ensure       => present,
  region       => 'sa-east-1',
  cidr_block   => '10.0.0.0/16',
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
  vpcs   => 'sample-vpc',
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

ec2_securitygroup { 'sample-sg':
  ensure      => present,
  description => 'Sample VPC security group to allow ssh',
  vpc_name    => 'sample-vpc',
  region      => 'sa-east-1',
  ingress     => [{
    protocol => 'tcp',
    port     => 22,
    cidr     => '0.0.0.0/0',
  }],
}

ec2_instance { 'sample-instance':
  ensure          => present,
  region          => 'sa-east-1',
  image_id        => 'ami-e08efbd0',
  instance_type   => 'm3.large',
  security_groups => 'sample-sg',
  subnet          => 'sample-subnet',
}
