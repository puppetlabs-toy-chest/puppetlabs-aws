Puppet::Type.newtype(:rds_db_parameter_group) do
  @doc = 'Type representing an RDS DB Paremeter group'

  ensurable

  newparam(:name, namevar: true) do
    desc 'the name of the DB Parameter Group (also known as the db_parameter_group_name)'
  end

  newproperty(:description) do
    desc 'the description of a DB parameter group'
  end

  newproperty(:db_parameter_group_family) do
    desc 'the name of the DB parameter group family that this DB parameter group is compatible with.'
  end

  newproperty(:region) do
    desc 'the region in which to create the db_parametergroup'
    validate do |value|
      fail 'region should not contain spaces' if value =~ /\s/
    end
  end

end