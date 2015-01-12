require_relative '../../../puppet_x/puppetlabs/aws.rb'
require "base64"

Puppet::Type.type(:rds_instance).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    regions.collect do |region|
      instances = []
      rds_client(region).describe_db_instances.each do |response|
        response.data.db_instances.each do |db|
            hash = db_instance_to_hash(region, db)
            instances << new(hash) if hash[:name]
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
    tags = rds_client(region).list_tags_for_resource(resource_name: get_arn_for_instance(region,instance.db_instance_identifier))

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
    }
    config
  end

  def exists?
    dest_region = resource[:region] if resource
    Puppet.info("Checking if instance #{name} exists in region #{dest_region || region}")
    [:present, :creating, :available].include? @property_hash[:ensure]
  end

  def create
    Puppet.info("Starting DB instance #{name}")
    groups = resource[:security_groups]
    groups = [groups] unless groups.is_a?(Array)
    groups = groups.reject(&:nil?)

    config = {
      db_instance_identifier: resource[:name],
      db_name: resource[:db_name],
      db_instance_class: resource[:db_instance_class],
      db_instance_identifier: resource[:db_name],
      db_instance_class: resource[:db_instance_class],
      vpc_security_group_ids: groups,
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
    }

    response = rds_client(resource[:region]).create_db_instance(config)

    @property_hash[:ensure] = :present
  end

  def destroy
    Puppet.info("Deleting instance #{name} in region #{resource[:region]}")
    rds = rds_client(resource[:region])
    Puppet.info("Skip Final Snapshot: #{resource[:skip_final_snapshot]}")
    config = {
      db_instance_identifier: resource[:name],
      skip_final_snapshot: resource[:skip_final_snapshot],
      final_db_snapshot_identifier: resource[:final_db_snapshot_identifier],
    }
    rds.delete_db_instance(config)
    @property_hash[:ensure] = :absent
  end

end
