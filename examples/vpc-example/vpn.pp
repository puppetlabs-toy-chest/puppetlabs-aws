ec2_vpc { 'sample2-vpc':
  ensure           => present,
  region           => 'sa-east-1',
  cidr_block       => '10.0.0.0/16',
  instance_tenancy => 'default',
}

ec2_vpc_vpn_gateway { 'sample2-vgw':
  ensure => present,
  region => 'sa-east-1',
  vpc    => 'sample2-vpc',
  type   => 'ipsec.1',
}

ec2_vpc_customer_gateway { 'sample2-cgw':
  ensure     => present,
  region     => 'sa-east-1',
  ip_address => '173.255.197.131',
  bgp_asn    => 65000,
  type       => 'ipsec.1',
}

ec2_vpc_vpn { 'sample2-vpn':
  ensure           => present,
  region           => 'sa-east-1',
  vpn_gateway      => 'sample2-vgw',
  customer_gateway => 'sample2-cgw',
  type             => 'ipsec.1',
  routes           => ['0.0.0.0/0'],
  static_routes    => true,
}
