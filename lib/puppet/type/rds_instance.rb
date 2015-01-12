Puppet::Type.newtype(:rds_instance) do
  @doc = 'type representing an RDS instance'

  ensurable do
    defaultvalues
    aliasvalue(:running, :present)
    newvalue(:stopped) do
      provider.stop
    end
  end

  newparam(:db_name, namevar: true) do
    desc 'the name of the db instance'
    validate do |value|
      fail 'Instances must have a db_name' if value == ''
    end
  end

  newparam(:security_groups, :array_matching => :all) do
    desc 'the security groups to associate the instance'
  end

  newproperty(:tags) do
    desc 'the tags for the instance'
  end

  newproperty(:region) do
    desc 'the region in which to launch the instance'
    validate do |value|
      fail 'region should not contain spaces' if value =~ /\s/
    end
  end

  newproperty(:db_instance_class) do
    desc 'the type to use for the instance (mysql, | postgres)'
    validate do |value|
      fail 'db_instance_class should not contain spaces' if value =~ /\s/
      fail 'db_instance_class should not be blank' if value == ''
    end
  end

  newproperty(:availability_zone_name) do
    desc 'the availability zone in which to place the instance'
    validate do |value|
      fail 'availability_zone_name should not contain spaces' if value =~ /\s/
      fail 'availability_zone_name should not be blank' if value == ''
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
    desc 'The IOPS stype for the DB (minimum 1000)'
    validate do |value|
      fail 'iops type should not contains spaces' if value =~ /\s/
    end
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
    desc 'The main user Password'
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

  autorequire(:ec2_securitygroup) do
    groups = self[:security_groups]
    groups.is_a?(Array) ? groups : [groups]
  end

end
