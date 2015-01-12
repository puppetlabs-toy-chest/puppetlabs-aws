ec2_vpc { 'garethr-test':
  ensure           => present,
  region           => 'sa-east-1',
  cidr_block       => '10.0.0.0/16',
  dhcp_options     => 'garethr-options',
  instance_tenancy => 'default',
}

ec2_vpc_dhcp_options { 'garethr-options':
  ensure            => present,
  region            => 'sa-east-1',
  netbios_node_type => 2,
}

ec2_vpc_subnet { 'garethr-subnet':
  ensure            => present,
  region            => 'sa-east-1',
  vpc               => 'garethr-test',
  cidr_block        => '10.0.0.0/24',
  availability_zone => 'sa-east-1a',
  route_table       => 'garethr-routes',
}

ec2_vpc_routetable { 'garethr-routes':
  ensure => present,
  region => 'sa-east-1',
  vpc    => 'garethr-test',
  routes => [
    { destination_cidr_block => '10.0.0.0/16', gateway => 'local' },
  ],
}

ec2_vpc_vpn_gateway { 'garethr-vgw':
  ensure => present,
  region => 'sa-east-1',
  vpc    => 'garethr-test',
  type   => 'ipsec.1',
}

ec2_vpc_internet_gateway { 'garethr-igw':
  ensure => present,
  region => 'sa-east-1',
  vpcs   => 'garethr-test',
}

ec2_vpc_customer_gateway { 'garethr-cgw':
  ensure     => present,
  region     => 'sa-east-1',
  ip_address => '173.255.197.131',
  bgp_asn    => 65000,
  type       => 'ipsec.1',
}

ec2_vpc_vpn { 'garethr-vpn':
  ensure           => present,
  region           => 'sa-east-1',
  vpn_gateway      => 'garethr-vgw',
  customer_gateway => 'garethr-cgw',
  type             => 'ipsec.1',
  routes           => ['0.0.0.0/0'],
  static_routes    => true,
}
