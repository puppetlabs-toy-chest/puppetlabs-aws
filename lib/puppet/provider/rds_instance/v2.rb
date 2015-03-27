require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:rds_instance).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    regions.collect do |region|
      instances = []
      rds_client(region).describe_db_instances.each do |response|
        response.data.db_instances.each do |db|
          unless db.db_instance_status =~ /^deleted$|^deleting$/
            hash = db_instance_to_hash(region, db)
            instances << new(hash) if hash[:name]
          end
        end
      end
      instances
    end.flatten
  end

  read_only(:auto_minor_version_upgrade,
    :backup_retention_period, :character_set_name, :creation_date_time,
    :iops, :master_username,
    :multi_az, :backup_window, :vpc_id, :license_model)

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region
      end
    end
  end

  def self.db_instance_to_hash(region, instance)
    if instance.respond_to?('skip_final_snapshot')
      skip_final_snapshot = instance.skip_final_snapshot
    else
      skip_final_snapshot = true
    end
    if instance.respond_to?('final_db_snapshot_identifier')
      final_db_snapshot_identifier = instance.final_db_snapshot_identifier
    else
      final_db_snapshot_identifier = ''
    end
    if instance.respond_to?('backup_retention_period')
      backup_retention_period = instance.backup_retention_period
    else
      backup_retention_period = 0
    end
    config = {
      ensure: :present,
      name: instance.db_instance_identifier,
      region: region,
      engine: instance.engine,
      db_instance_class: instance.db_instance_class,
      master_username: instance.master_username,
      db_name: instance.db_name,
      allocated_storage: instance.allocated_storage,
      storage_type: instance.storage_type,
      license_model: instance.license_model,
      multi_az: instance.multi_az,
      iops: instance.iops,
      backup_retention_period: backup_retention_period,
      skip_final_snapshot: skip_final_snapshot,
      final_db_snapshot_identifier: final_db_snapshot_identifier,
      db_parameter_group_name: instance.db_parameter_groups.collect(&:db_parameter_group_name).first,
      db_security_groups: instance.db_security_groups.collect(&:db_security_group_name),
    }
    if instance.respond_to?('endpoint')
      config[:endpoint] = instance.endpoint.address
      config[:port]     = instance.endpoint.port
    end
    config
  end

  def exists?
    dest_region = resource[:region] if resource
    Puppet.info("Checking if instance #{name} exists in region #{dest_region || region}")
    [:present, :creating, :available, :backing_up].include? @property_hash[:ensure]
  end

  def create
    Puppet.info("Starting DB instance #{name}")
    config = {
      db_instance_identifier: resource[:name],
      db_name: resource[:db_name],
      db_instance_class: resource[:db_instance_class],
      engine: resource[:engine],
      engine_version: resource[:engine_version],
      license_model: resource[:license_model],
      storage_type: resource[:storage_type],
      multi_az: resource[:multi_az],
      allocated_storage: resource[:allocated_storage],
      iops: resource[:iops],
      master_username: resource[:master_username],
      master_user_password: resource[:master_user_password],
      db_subnet_group_name: resource[:db_subnet_group_name],
      db_security_groups: resource[:db_security_groups],
      db_parameter_group_name: resource[:db_parameter_group_name],
    }

    rds_client(resource[:region]).create_db_instance(config)

    @property_hash[:ensure] = :present
  end

  def destroy
    Puppet.info("Deleting database #{name} in region #{resource[:region]}")
    rds = rds_client(resource[:region])
    Puppet.info("Skip Final Snapshot: #{resource[:skip_final_snapshot]}")
    config = {
      db_instance_identifier: name,
      skip_final_snapshot: skip_final_snapshot,
      final_db_snapshot_identifier: final_db_snapshot_identifier,
    }
    rds.delete_db_instance(config)
    @property_hash[:ensure] = :absent
  end

end