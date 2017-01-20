require_relative '../../puppet_x/puppetlabs/property/region.rb'

Puppet::Type.newtype(:rds_db_parameter_group) do
  @doc = 'Type representing an RDS DB Parameter group.'

  newparam(:name, namevar: true) do
    desc 'The name of the DB Parameter Group (also known as the db_parameter_group_name).'
    validate do |value|
      fail 'name should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:description) do
    desc 'The description of a DB parameter group.'
    validate do |value|
      fail 'description should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:family) do
    desc 'The name of the DB family that this DB parameter group is compatible with (eg. mysql5.1).'
    validate do |value|
      fail 'family should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:region, :parent => PuppetX::Property::AwsRegion) do
    desc 'The region in which to create the db_parameter_group.'
  end

end
