require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:rds_db_securitygroup).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    regions.collect do |region|
      instances = []
      rds_client(region).describe_db_security_groups.each do |response|
        response.data.db_security_groups.each do |db_security_group|
          hash = db_security_group_to_hash(region, db_security_group)
          instances << new(hash) if hash[:name]
        end
      end
      instances
    end.flatten
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region
      end
    end
  end

  read_only(:owner_id)

  def self.db_security_group_to_hash(region, db_security_group)
    {
      :ensure => :present,
      :name => db_security_group.db_security_group_name,
      :db_security_group_description => db_security_group.db_security_group_description,
      :owner_id => db_security_group.owner_id,
    }
  end

  def exists?
    Puppet.info("Checking if DB Security Group #{name} exists")
    [:present, :creating, :available].include? @property_hash[:ensure]
  end

  def create
    Puppet.info("Starting DB instance #{name}")
    config = {
      :db_security_group_name => resource[:name],
      :db_security_group_description => resource[:db_security_group_description],
    }

    rds_client(resource[:region]).create_db_security_group(config)

    @property_hash[:ensure] = :present
  end

  def destroy
    Puppet.info("Deleting DB Security Group #{name} in region #{resource[:region]}")
    rds = rds_client(resource[:region])
    config = {
      db_security_group_name: name,
    }
    rds.delete_db_instance(config)
    @property_hash[:ensure] = :absent
  end

end