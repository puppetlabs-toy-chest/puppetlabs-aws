Puppet::Type.newtype(:rds_instance) do
  @doc = 'Type representing an RDS instance.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'the name of the db instance (also known as the db_instance_identifier)'
    validate do |value|
      fail 'RDS Instances must have a name' if value == ''
    end
  end

  newproperty(:db_name) do
    desc 'The meaning of this parameter differs according to the database engine you use.
Type: String

MySQL

The name of the database to create when the DB instance is created. If this parameter is not specified, no database is created in the DB instance.

Constraints:

Must contain 1 to 64 alphanumeric characters
Cannot be a word reserved by the specified database engine

PostgreSQL

The name of the database to create when the DB instance is created. If this parameter is not specified, no database is created in the DB instance.

Constraints:

Must contain 1 to 63 alphanumeric characters
Must begin with a letter or an underscore. Subsequent characters can be letters, underscores, or digits (0-9).
Cannot be a word reserved by the specified database engine
Oracle

The Oracle System ID (SID) of the created DB instance.

Default: ORCL

Constraints:

Cannot be longer than 8 characters
SQL Server

Not applicable. Must be null.'
  end

  newproperty(:region) do
    desc 'the region in which to launch the instance'
    validate do |value|
      fail 'region should not contain spaces' if value =~ /\s/
    end
  end

  newproperty(:db_instance_class) do
    desc 'the instance class to use for the instance eg. db.m3.medium'
    validate do |value|
      fail 'db_instance_class should not contain spaces' if value =~ /\s/
      fail 'db_instance_class should not be blank' if value == ''
    end
  end

  newproperty(:availability_zone) do
    desc 'the availability zone in which to place the instance'
    validate do |value|
      fail 'availability_zone should not contain spaces' if value =~ /\s/
      fail 'availability_zone should not be blank' if value == ''
    end
  end

  newproperty(:engine) do
    desc 'the type of Database for the instance( mysql, postgres, etc...)'
    validate do |value|
      fail 'engine type should not contains spaces' if value =~ /\s/
      fail 'engine should not be blank' if value == ''
    end
  end

  newproperty(:engine_version) do
    desc 'the version of Database for the instance'
    validate do |value|
      fail 'engine_version type should not contains spaces' if value =~ /\s/
      fail 'engine_version should not be blank' if value == ''
    end
  end

  newproperty(:allocated_storage) do
    desc 'The size of the DB'
    validate do |value|
      fail 'allocated_storage type should not contains spaces' if value =~ /\s/
      fail 'allocated_storage should not be blank' if value == ''
    end
  end

  newproperty(:license_model) do
    desc 'the license for the instance (iValid values: license-included | bring-your-own-license | general-public-license)'
    validate do |value|
      fail 'license_model type should not contains spaces' if value =~ /\s/
    end
  end

  newproperty(:storage_type) do
    desc 'The storage stype for the DB (Valid values: gp | io1  *Note: If you specify io1, you must also include a value for the Iops parameter)'
    validate do |value|
      fail 'storage_type type should not contains spaces' if value =~ /\s/
    end
  end

  newproperty(:iops) do
    desc 'The IOPS stype for the DB.'
    newvalue(/\d+/)
  end

  newproperty(:master_username) do
    desc 'The main user for the DB'
    validate do |value|
      fail 'master_username type should not contains spaces' if value =~ /\s/
    end
  end

  newproperty(:master_user_password) do
    desc 'The main user Password'
    validate do |value|
      fail 'master_user_password should not be blank' if value == ''
    end
  end

  newproperty(:multi_az) do
    desc 'Define a multi-az'
    validate do |value|
      fail 'multi_az should not be blank' if value == ''
    end
  end

  newproperty(:db_subnet_group_name) do
    desc 'The VPC subnet for this instance.'
    validate do |value|
      fail 'db_subnet_group_name should not be blank' if value == ''
    end
  end

  newproperty(:db_security_groups, :array_matching => :all) do
    desc 'the DB security groups to assign to this RDS instance'
  end

  newproperty(:endpoint) do
    desc 'the connection endpoint for the database'
  end

  newproperty(:port) do
    desc 'the port the database is running on'
  end

  newproperty(:skip_final_snapshot) do
    desc 'Skip snapshot on deletion.'
    defaultto :true
    newvalues(:false, :'false',:'true')
  end

  newproperty(:db_parameter_group_name) do
    desc 'the DB parameter group for this RDS instance'
  end

  newproperty(:final_db_snapshot_identifier) do
    desc 'Name given to the last snapshot on deletion.'
    validate do |value|
      fail 'final_db_snapshot_identifier should not be blank' if value == ''
    end
  end

end