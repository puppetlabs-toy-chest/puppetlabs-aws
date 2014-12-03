ec2_securitygroup { 'test-sg':
  region      => 'sa-east-1',
  ensure      => present,
  description => 'Security group for audit',
  ingress     => [{
    security_group => 'test-sg',
  }],
}
