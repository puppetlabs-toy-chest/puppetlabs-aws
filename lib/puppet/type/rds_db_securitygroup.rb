Puppet::Type.newtype(:rds_db_securitygroup) do
  @doc = 'Type representing an RDS instance.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'the name of the DB Security Group (also known as the db_security_group_name)'
  end

  newparam(:db_security_group_description) do
    desc 'the description of a DB Security group'
    validate do |value|
      fail 'db_security_group_description should not be blank' if value == ''
    end
  end

  newproperty(:owner_id) do
    desc 'the ID of the owner of this DB Security Group'
  end

  newproperty(:ec2_security_groups, :array_matching => :all) do
    desc 'the EC2 Security Groups assigned to this RDS DB security group'
  end

  newproperty(:region) do
    desc 'the region in which to create the db_securitygroup'
    validate do |value|
      fail 'region should not contain spaces' if value =~ /\s/
    end
  end

  newproperty(:ip_ranges, :array_matching => :all) do
    desc 'the IP ranges allowed to access the RDS instance'
  end

end