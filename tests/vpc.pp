ec2_vpc { 'test-vpc':
  ensure     => present,
  cidr_block => '10.0.0.0/16',
  region     => 'sa-east-1',
}

ec2_vpc_subnet { 'test-subnet':
  ensure     => present,
  cidr_block => '10.0.0.0/24',
  region     => 'sa-east-1',
  vpc        => 'test-vpc',
}

ec2_vpc_internet_gateway { 'test-gateway':
  ensure => present,
  region => 'sa-east-1',
  vpcs   => ['test-vpc'],
}
