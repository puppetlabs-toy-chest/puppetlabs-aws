ec2_securitygroup { 'rds-postgres-group':
  ensure           => present,
  region           => 'us-west-2',
  description      => 'Group for Allowing access to Postgres (Port 5432)',
  ingress          => [{
    security_group => 'rds-postgres-group',
  },{
    protocol => 'tcp',
    port     => 5432,
    cidr     => '0.0.0.0/0',
  }]
}

rds_db_securitygroup { 'rds-postgres-db_securitygroup':
  ensure      => present,
  region      => 'us-west-2',
  description => 'An RDS Security group to allow Postgres',
}
