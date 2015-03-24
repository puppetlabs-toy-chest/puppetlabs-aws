ec2_securitygroup { 'sample-sg':
  ensure   => absent,
  region => 'sa-east-1',
} ~>

ec2_vpc_internet_gateway { 'sample-igw':
  ensure => absent,
  region => 'sa-east-1',
} ~>

ec2_vpc_subnet { 'sample-subnet':
  ensure => absent,
  region => 'sa-east-1',
} ~>

ec2_vpc_routetable { 'sample-routes':
  ensure => absent,
  region => 'sa-east-1',
} ~>

ec2_vpc { 'sample-vpc':
  ensure => absent,
  region => 'sa-east-1',
} ~>

ec2_vpc_dhcp_options { 'sample-options':
  ensure => absent,
  region => 'sa-east-1',
}
