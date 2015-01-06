/*
ec2_vpc { 'garethr-test':
  region     => 'sa-east-1',
  cidr_block => '10.0.0.0/16',
}

ec2_vpc_internet_gateway { 'garethr-igw':
  region => 'sa-east-1',
  vpcs   => 'garethr-test',
}

ec2_vpc_subnet { 'garethr-subnet':
  region            => 'sa-east-1',
  vpc               => 'garethr-test',
  cidr_block        => '10.0.0.0/24',
  availability_zone => 'sa-east-1a',
}

ec2_vpc_routetable { 'garethr-routes':
  region => 'sa-east-1',
  vpc    => 'garethr-test',
  routes => [
    { destination_cidr_block => '0.0.0.0/0', gateway => 'local' },
  ],
}
*/

ec2_vpc_dhcp_options { 'garethr-options':
  region            => 'sa-east-1',
  netbios_node_type => 2,
}

/*
ec2_vpc_customer_gateway { 'gareth-cgw':
  region     => 'sa-east-1',
  ip_address => '',
  bgp_asn    => '',
  type       => 'ipsec.1',
}

ec2_virtual_private_gateway { 'garethr-vgw':
  region            => 'sa-east-1',
  vpc               => 'garethr-vpc',
  vpn_type          => '',
  availability_zone => 'sa-east-1a',
}

ec2_vpc_vpn { 'garethr-vpn':
  region                  => 'sa-east-1',
  virtual_private_gateway => 'garethr-vgw',
  type                    => '',
  routing                 => '',
  static_routes           => '',
}
*/
