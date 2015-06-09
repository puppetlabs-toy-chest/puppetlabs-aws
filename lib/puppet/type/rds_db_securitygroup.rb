Puppet::Type.newtype(:rds_db_securitygroup) do
  @doc = 'Type representing an RDS instance.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the DB Security Group (also known as the db_security_group_name).'
    validate do |value|
      fail 'name should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:description) do
    desc 'The description of a DB Security group.'
    validate do |value|
      fail 'description should be a String' unless value.is_a?(String)
      fail 'description should not be blank' if value == ''
    end
  end

  newproperty(:owner_id) do
    desc 'The ID of the owner of this DB Security Group.'
    validate do |value|
      fail 'owner_id is read-only'
    end
  end

  newproperty(:security_groups, :array_matching => :all) do
    desc 'The EC2 Security Groups assigned to this RDS DB security group.'
    validate do |value|
      fail 'security_groups is read-only'
    end
  end

  newproperty(:region) do
    desc 'The region in which to create the db_securitygroup.'
    validate do |value|
      fail 'region should be a String' unless value.is_a?(String)
      fail 'region should not contain spaces' if value =~ /\s/
    end
  end

  newproperty(:ip_ranges, :array_matching => :all) do
    desc 'The IP ranges allowed to access the RDS instance.'
    validate do |value|
      fail 'ip_ranges is read-only'
    end
  end

  autorequire(:ec2_securitygroup) do
    groups = self[:security_groups]
    groups.is_a?(Array) ? groups : [groups]
  end

end
