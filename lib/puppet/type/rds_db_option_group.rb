Puppet::Type.newtype(:rds_db_option_group) do
  @doc = 'Type representing an RDS DB Option group.'

  newparam(:name, namevar: true) do
    desc 'The name of the DB Option Group (also known as the db_option_group_name).'
    validate do |value|
      fail 'name should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:description) do
    desc 'The description of a DB option group.'
    validate do |value|
      fail 'description should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:options) do
    desc 'The additional options to apply to the RDS instance'
    validate do |value|
      fail 'description should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:region) do
    desc 'The region in which to create the db_option_group.'
    validate do |value|
      fail 'region should be a String' unless value.is_a?(String)
      fail 'region should not contain spaces' if value =~ /\s/
    end
  end
end
