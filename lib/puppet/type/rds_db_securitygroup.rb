Puppet::Type.newtype(:rds_db_securitygroup) do
  @doc = 'Type representing an RDS instance.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'the name of the DB Security Group (also known as the db_security_group_name)'
  end

  newproperty(:db_security_group_description) do
    desc 'the description of a DB Security group'
    validate do |value|
      fail 'db_security_group_description should not be blank' if value == ''
    end
  end

end