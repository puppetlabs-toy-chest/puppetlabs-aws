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

  read_only(:allocated_storage, :auto_minor_version_upgrade, :availability_zone_name,
            :backup_retention_period, :character_set_name, :creation_date_time,
            :db_instance_class, :instance_id, :db_name, :engine, :engine_version, :iops, :master_username,
            :multi_az, :backup_window, :vpc_id, :license_model)

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region
      end
    end
  end

  def self.db_instance_to_hash(region, instance)
    #tags = {}
    #instance.tags.each do |tag|
    #  tags[tag.key] = tag.value unless tag.key == 'Name'
    #end
    config = {
      db_instance_class: instance.db_instance_class,
      #instance_id: instance.instance_id,
      master_username: instance.master_username,
    #  availability_zone_name: instance.availability_zone_name,
    #  tags: tags,
      db_name: instance.db_name,
      allocated_storage: instance.allocated_storage,
      storage_type: instance.storage_type,
      license_model: instance.license_model,
      multi_az: instance.multi_az,
      iops: instance.iops,
      master_user_password: instance.master_user_password,
      db_name: instance.db_name,
      db_subnet_group_name: instance.db_subnet_group_name,
    }
    config
  end

  def exists?
    dest_region = resource[:region] if resource
    Puppet.info("Checking if instance #{name} exists in region #{dest_region || region}")
    [:present, :pending, :running].include? @property_hash[:ensure]
  end

  def stopped?
    dest_region = resource[:region] if resource
    Puppet.info("Checking if instance #{name} is stopped in region #{dest_region || region}")
    [:stopping, :stopped].include? @property_hash[:ensure]
  end

  def create
    Puppet.info("Starting DB instance #{name}")
    groups = resource[:security_groups]
    groups = [groups] unless groups.is_a?(Array)
    groups = groups.reject(&:nil?)

    if stopped?
      restart
    else
      config = {
        db_instance_identifier: resource[:db_name],
        db_instance_class: resource[:db_instance_class],
        #availability_zone_name: resource[:availability_zone_name],
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

      #tags = resource[:tags] ? resource[:tags].map { |k,v| {key: k, value: v} } : []
      #tags << {key: 'Name', value: name}
      #rds_client(resource[:region]).create_tags(
      #  resources: response.instances.map(&:instance_id),
      #  tags: tags)
    end
  end

#  def tags=(value)
#    Puppet.info("Updating tags for #{name} in region #{region}")
#    ec2_client(resource[:region]).create_tags(
#      resources: [instance_id],
#      tags: value.collect { |k,v| { :key => k, :value => v } }
#    ) unless value.empty?
#    missing_tags = tags.keys - value.keys
#    ec2_client(resource[:region]).delete_tags(
#      resources: [instance_id],
#      tags: missing_tags.collect { |k| { :key => k } }
#    ) unless missing_tags.empty?
#  end

  def destroy
    Puppet.info("Deleting instance #{name} in region #{resource[:region]}")
#    rds = rds_client(resource[:region])
#    instance = rds.describe_db_instances
#    instance_ids = instances.reservations.map(&:instances).flatten.map(&:instance_id)
#    rds.terminate_instances(instance_ids: instance_ids)
#    rds.wait_until(:instance_terminated, instance_ids: instance_ids)
    @property_hash[:ensure] = :absent
  end

end
