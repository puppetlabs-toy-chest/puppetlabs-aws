ec2_vpc { 'test-vpc':
  ensure     => present,
  cidr_block => '10.0.0.0/16',
  region     => 'sa-east-1',
}

ec2_vpc_subnet { 'test-subnet':
  ensure            => present,
  cidr_block        => '10.0.0.0/24',
  region            => 'sa-east-1',
  vpc               => 'test-vpc',
  availability_zone => 'sa-east-1a',
}

ec2_vpc_internet_gateway { 'test-gateway':
  ensure => present,
  region => 'sa-east-1',
  vpcs   => ['test-vpc'],
}

ec2_vpc_route_table { 'test-route-table':
  ensure => present,
  region => 'sa-east-1',
  vpc    => 'test-vpc',
  routes => [
    {
      destination_cidr_block => '0.0.0.0/0',
      gateway                => 'test-gateway',
    },{
      destination_cidr_block => '10.0.0.0/16',
      gateway                => 'local',
    }

  ]
}

ec2_securitygroup { 'vpc-sg':
  ensure      => present,
  region      => 'sa-east-1',
  description => 'Security group for VPC',
  vpc         => 'test-vpc',
  ingress     => [{
    protocol => 'tcp',
    port     => 80,
    cidr     => '0.0.0.0/0'
  }],
}

ec2_instance { 'vpc-1':
  ensure            => present,
  region            => 'sa-east-1',
  image_id          => 'ami-6dd26770',
  security_groups   => ['vpc-sg'],
  availability_zone => 'sa-east-1a',
  subnet            => 'test-subnet',
  instance_type     => 't2.micro',
  tags              => {
    department => 'engineering',
    project    => 'cloud',
    created_by => 'garethr'
  }
}
