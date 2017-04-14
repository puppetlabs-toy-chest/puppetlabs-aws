require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:rds_instance).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws
  confine feature: :retries

  mk_resource_methods
  remove_method :rds_tags=

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
            :db_parameter_group, :backup_retention_period, :db_subnet)

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region
      end
    end
  end

  def self.db_instance_to_hash(region, instance)
    db_subnet = instance.db_subnet_group ? instance.db_subnet_group.db_subnet_group_name : nil

    # tags stuff requires aws sdk >= 2.6.11
    rds_tags = {}
    db_tags = rds_client(region).list_tags_for_resource( resource_name: instance.db_instance_arn )
    db_tags.tag_list.each do |rds_tag|
      rds_tags[rds_tag.key] = rds_tag.value unless rds_tag.key == 'Name'
    end

    vpc_security_groups = self.security_group_names_from_ids(region, instance.vpc_security_groups.collect(&:vpc_security_group_id))

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
      rds_tags: rds_tags,
      db_subnet: db_subnet,
      db_parameter_group: instance.db_parameter_groups.collect(&:db_parameter_group_name).first,
      db_security_groups: instance.db_security_groups.collect(&:db_security_group_name),
      vpc_security_groups: vpc_security_groups,
      backup_retention_period: instance.backup_retention_period,
      availability_zone: instance.availability_zone,
      arn: instance.db_instance_arn
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

  def vpc_security_groups=(value)
    @property_flush[:vpc_security_group_ids] = self.class.vpc_security_group_ids_from_mixed(resource[:region], resource[:vpc_security_groups])
  end

  # Convert either a VPC security group name or ID to a name. Allows `insync?`
  # to work when the resource contains IDs, for backwards compatibility. Lives
  # in the provider for access to the resource's region.
  def vpc_security_group_munge(value)
    self.class.vpc_security_group_names_from_mixed(resource[:region], [value]).first
  end

  # Given a list of mixed VPC security group IDs and names, return them all as
  # IDs only. This is for backwards compatibility.
  def self.vpc_security_group_ids_from_mixed(region, security_groups)
    vpc_sg_ids = []
    vpc_sg_names_to_discover = []

    security_groups.each do |sg|
      if sg =~ /sg-[0-9a-fA-F]{8,}/
        vpc_sg_ids << sg
      else
        vpc_sg_names_to_discover << sg
      end
    end

    unless vpc_sg_names_to_discover.empty?
      vpc_sg_ids += self.security_group_ids_from_names(region, vpc_sg_names_to_discover)
    end

    vpc_sg_ids
  end

  # Given a list of mixed VPC security group IDs and names, return them all as
  # namess only. This is for backwards compatibility.
  def self.vpc_security_group_names_from_mixed(region, security_groups)
    vpc_sg_names = []
    vpc_sg_ids_to_discover = []

    security_groups.each do |sg|
      if sg =~ /sg-[0-9a-fA-F]{8,}/
        vpc_sg_ids_to_discover << sg
      else
        vpc_sg_names << sg
      end
    end

    unless vpc_sg_ids_to_discover.empty?
      vpc_sg_names += self.security_group_names_from_ids(region, vpc_sg_ids_to_discover)
    end

    vpc_sg_names
  end

  def exists?
    dest_region = resource[:region] if resource
    Puppet.debug("Checking if instance #{name} exists in region #{dest_region || region}")
    [:present, :creating, :available, :backing_up].include? @property_hash[:ensure]
  end

  def create
    tags = resource[:rds_tags] ? resource[:rds_tags].map { |k,v| {key: k, value: v} } : []
    tags << {key: 'Name', value: name}

    if resource[:vpc_security_groups] and not resource[:vpc_security_groups].empty?
      vpc_sg_ids = self.class.vpc_security_group_ids_from_mixed(resource[:region], resource[:vpc_security_groups])
    end

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
      vpc_security_group_ids: vpc_sg_ids,
      backup_retention_period: resource[:backup_retention_period],
      availability_zone: resource[:availability_zone],
      tags: tags,
    }

    if resource[:restore_snapshot]
      Puppet.info("Restoring DB instance #{name} from snapshot #{resource[:restore_snapshot]}")

      # Restoring from a snapshot implies these properties and they cannot be
      # included in the call to the AWS API. If any don't match the resource,
      # Puppet will (try to) change them next run.
      remove_from_config = [
        :allocated_storage,
        :backup_retention_period,
        :db_parameter_group_name,
        :db_security_groups,
        :engine_version,
        :master_user_password,
        :master_username,
        :vpc_security_group_ids,
      ]

      if ['mariadb', 'mysql', 'postgres'].include?(resource[:engine].downcase)
        remove_from_config << :db_name
      end

      remove_from_config.each { |k| config.delete(k) }

      config[:db_snapshot_identifier] = resource[:restore_snapshot]

      rds_client(resource[:region]).restore_db_instance_from_db_snapshot(config)
    else
      Puppet.info("Starting DB instance #{name}")
      rds_client(resource[:region]).create_db_instance(config)
    end

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
    if @property_hash[:ensure] != :absent and not @property_flush.nil?
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

        rds_client(@property_hash[:region]).modify_db_instance(rds_instance_update)
      end
    end

  end

end
