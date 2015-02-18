ec2_vpc_vpn { 'sample2-vpn':
  ensure => absent,
  region => 'sa-east-1',
} ~>

ec2_vpc_customer_gateway { 'sample2-cgw':
  ensure => absent,
  region => 'sa-east-1',
} ~>

ec2_vpc_vpn_gateway { 'sample2-vgw':
  ensure => absent,
  region => 'sa-east-1',
} ~>

ec2_vpc_routetable { 'sample2-routes':
  ensure => absent,
  region => 'sa-east-1',
} ~>

ec2_vpc { 'sample2-vpc':
  ensure => absent,
  region => 'sa-east-1',
}
