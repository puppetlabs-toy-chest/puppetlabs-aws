# RDS

[Amazon Relational Database Service](http://aws.amazon.com/rds/) (Amazon RDS) is a web service that makes it easy to set up, operate, and scale a relational database in the cloud.

## How

This example creates a security group to allow access to a Postgres RDS instance, then creates that RDS instance with the security group assigned.

    puppet apply rds_security.pp

Unfortunately, it's not possible to assign the EC2 group and the allowed IPs to the `db_securitygroup` through the API, so you have to do this manually though the console for now:

## Add the Security Group We Made with Puppet**
![Add EC2 Security Group](./images/add-rds-securitygroup.png?raw=true)

## Add an IP to allow access to the RDS instance
**Note: Enter `0.0.0.0/32` to allow all IPs**
![Add IP to allow](./images/add-ip-to-allow.png?raw=true)

## It should look something like this
![Final Look](./images/final-screen.png?raw=true)

You can now check to see if your security group is correct by using `puppet resource` commands:

    puppet resource rds_db_securitygroup rds-postgres-db_securitygroup

It should return something like this:

~~~
rds_db_securitygroup { 'rds-postgres-db_securitygroup':
  ensure              => 'present',
  ec2_security_groups => [{'ec2_security_group_id' => 'sg-83fb3z5', 'ec2_security_group_name' => 'rds-postgres-group', 'ec2_security_group_owner_id' => '4822239859', 'status' => 'authorized'}],
  ip_ranges           => [{'ip_range' => '0.0.0.0/32', 'status' => 'authorized'}],
  owner_id            => '239838031',
  region              => 'us-west-2',
}
~~~

When this is complete, create the RDS Postgres instance:

    puppet apply rds_postgres.pp

This can take a while to set up, but when it's complete, you should be able to access it:

~~~
psql -d postgresql -h puppetlabs-aws-postgres.cwgutxb9fmx.us-west-2.rds.amazonaws.com -U root

Password for user root: pullZstringz345
psql (9.4.0, server 9.3.5)
SSL connection (protocol: TLSv1.2, cipher: DHE-RSA-AES256-GCM-SHA384, bits: 256, compression: off)
Type "help" for help.

postgresql=> exit
~~~
