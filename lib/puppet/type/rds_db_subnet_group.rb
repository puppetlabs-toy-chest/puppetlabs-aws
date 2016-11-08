require_relative '../../puppet_x/puppetlabs/property/tag.rb'

Puppet::Type.newtype(:rds_db_subnet_group) do
  @doc = 'Type for the RDS DB subnet group which relies on the existence of corresponding ec2_subnets. Subnets are required to be in seperate AZs'

  ensurable

  #required
  newparam(:name, namevar: true) do
    desc 'The name of the RDS DB subnet group (db_subnet_group_name.)'
    validate do |value|
      fail 'RDS DB Subnet group must have a name' if value == ''
      fail 'RDS DB Subnet group name cannot be default. It is a reserved name' if value =~ /^default$/
      fail 'RDS DB Subnet group name must be a string' unless value.is_a?(String)
    end
  end

  #required
  newproperty(:description) do
    desc 'a short description of the RDS DB subnet group (db_subnet_group_description)'
    validate do |value|
      fail 'description cannot be blank' if value == ''
      fail 'description should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:region) do
    desc 'The region to deploy the RDS DB Subnet group, should be same region as associated rds_instance'
    validate do |value|
      fail 'region must not contain spaces' if value =~ /\s/
      fail 'region should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:vpc) do
    desc 'VPC to deploy the RDS DB Subnet group, should be same as VPC associated to rds_instance .'
    validate do |value|
      fail 'vpc should be a String' unless value.is_a?(String)
    end
  end

  #required
  newproperty(:subnets, :array_matching => :all) do
    desc 'The subnets in which to launch the RDS DB Subnet Group. DB subnet groups must contain at least one subnet in at least two AZs in the region.'
    validate do |value|
      fail 'subnets should be a String' unless value.is_a?(String)
    end
    def insync?(is)
      is.to_set == should.to_set
    end
  end

  autorequire(:ec2_vpc_subnet) do
    subnets = self[:subnets]
    subnets.is_a?(Array) ? subnets : [subnets]
  end

  autorequire(:ec2_vpc) do
    self[:vpc]
  end

end

