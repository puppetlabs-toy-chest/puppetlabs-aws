ec2_vpc { 'test2-vpc':
  ensure     => absent,
  cidr_block => '10.0.0.0/16',
  region     => 'sa-east-1',
}
