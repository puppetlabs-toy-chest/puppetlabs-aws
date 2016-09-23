require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:rds_instance).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def initialize(value={})
    super(value)
    @property_flush = {}
  end

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

  read_only(:master_username, :multi_az, :license_model, :db_name, :region,
            :availability_zone, :engine, :engine_version, :db_security_groups,
            :db_parameter_group, :backup_retention_period, :db_subnet,
            :vpc_security_groups)

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region
      end
    end
  end

  def self.db_instance_to_hash(region, instance)
    db_subnet = instance.db_subnet_group ? instance.db_subnet_group.db_subnet_group_name : nil
    config = {
      ensure: :present,
      name: instance.db_instance_identifier,
      region: region,
      engine: instance.engine,
      engine_version: instance.engine_version,
      db_instance_class: instance.db_instance_class,
      master_username: instance.master_username,
      db_name: instance.db_name,
      allocated_storage: instance.allocated_storage,
      storage_type: instance.storage_type,
      license_model: instance.license_model,
      multi_az: instance.multi_az,
      iops: instance.iops,
      db_subnet: db_subnet,
      db_parameter_group: instance.db_parameter_groups.collect(&:db_parameter_group_name).first,
      db_security_groups: instance.db_security_groups.collect(&:db_security_group_name),
      vpc_security_groups: instance.vpc_security_groups.collect(&:vpc_security_group_id),
      backup_retention_period: instance.backup_retention_period,
      availability_zone: instance.availability_zone
    }
    if instance.respond_to?('endpoint') && !instance.endpoint.nil?
      config[:endpoint] = instance.endpoint.address
      config[:port]     = instance.endpoint.port
    end
    config
  end

  def db_instance_class=(value)
    @property_flush[:db_instance_class] = value
  end

  def allocated_storage=(value)
    @property_flush[:allocated_storage] = value
  end

  def storage_type=(value)
    @property_flush[:storage_type] = value
  end

  def iops=(value)
    @property_flush[:iops] = value
  end

  def exists?
    dest_region = resource[:region] if resource
    Puppet.debug("Checking if instance #{name} exists in region #{dest_region || region}")
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
      multi_az: resource[:multi_az].to_s,
      allocated_storage: resource[:allocated_storage],
      iops: resource[:iops],
      master_username: resource[:master_username],
      master_user_password: resource[:master_user_password],
      db_subnet_group_name: resource[:db_subnet],
      db_security_groups: resource[:db_security_groups],
      db_parameter_group_name: resource[:db_parameter_group],
      vpc_security_group_ids: resource[:vpc_security_groups],
      backup_retention_period: resource[:backup_retention_period],
      availability_zone: resource[:availability_zone],
    }

    rds_client(resource[:region]).create_db_instance(config)

    @property_hash[:ensure] = :present
  end

  def destroy
    Puppet.info("Deleting database #{name} in region #{resource[:region]}")
    rds = rds_client(resource[:region])
    if resource[:skip_final_snapshot].to_s == 'true'
      Puppet.info("A snapshot of the database on deletion will be available as #{resource[:final_db_snapshot_identifier]}")
    end
    config = {
      db_instance_identifier: name,
      skip_final_snapshot: resource[:skip_final_snapshot].to_s,
      final_db_snapshot_identifier: resource[:final_db_snapshot_identifier],
    }
    rds.delete_db_instance(config)
    @property_hash[:ensure] = :absent
  end

  def flush
    if @property_hash[:ensure] != :absent
      Puppet.debug("Flushing RDS instance for #{@property_hash[:name]}")

      if @property_flush.keys.size > 0
        rds_instance_update = {
          db_instance_identifier: @property_hash[:name]
        }

        # The only items in the @property_flush should map directly to the
        # key/values of the modify_db_instance method on the client.  To add
        # modify support for more values, create a setter method for the type's
        # parameter matching the RDS client update hash.
        #
        @property_flush.each {|k,v|
          rds_instance_update[k] = v
        }

        rds_client.modify_db_instance(rds_instance_update)
      end
    end

  end

end
