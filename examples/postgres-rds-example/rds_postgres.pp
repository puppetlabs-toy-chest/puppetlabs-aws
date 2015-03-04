rds_instance { 'puppetlabs-aws-postgres':
  ensure              => present,
  allocated_storage   => '5',
  db_instance_class   => 'db.m3.medium',
  db_name             => 'postgresql',
  engine              => 'postgres',
  license_model       => 'postgresql-license',
  db_security_groups  => 'rds-postgres-db_securitygroup',
  master_username     => 'root',
  master_user_password=> 'pullZstringz345',
  region              => 'us-west-2',
  skip_final_snapshot => 'true',
  storage_type        => 'gp2',
}
