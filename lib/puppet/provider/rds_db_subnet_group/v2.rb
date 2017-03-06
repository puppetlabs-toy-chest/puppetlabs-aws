require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:rds_db_subnet_group).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances()
    Puppet.debug('Retrieving rds db subnets')
    regions.collect do |region|
      rds_subnets = []
      rds_client(region).describe_db_subnet_groups.each do |response|
        response.data.db_subnet_groups.each do |db_subnet_group|
          unless db_subnet_group.db_subnet_group_name =~ /^default$/
            hash = db_subnet_group_to_hash(region, db_subnet_group)
            rds_subnets << new(hash) if hash[:name]
          end
        end
      end
      rds_subnets
    end.flatten
  end

  def self.prefetch(resources)
    instances().each do |prov|
      if resource = resources[prov.name]  # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region
      end
    end
  end

  read_only(:vpc, :region )

  def self.db_subnet_group_to_hash(region, db_subnet_group)
    Puppet.debug("Checking for #{db_subnet_group.db_subnet_group_name} rds db subnet")
    if vpc = db_subnet_group.vpc_id
      name = vpc_name_from_id(region, vpc)
      unless name.nil?
        vpc_name = name
      end
    end

    subnet_data = db_subnet_group.subnets
    subnet_ids = subnet_data.map{|x| x[:subnet_identifier]}
    subnet_names = []
    subnet_response = ec2_client(region).describe_subnets(subnet_ids: subnet_ids)
    subnet_response.data.subnets.each do |subnet|
      subnet_name_tag = subnet.tags.detect { |tag| tag.key == 'Name'}
      if subnet_name_tag
        subnet_names << subnet_name_tag.value
      end
    end

    {
         :ensure      => :present,
         :name        => db_subnet_group.db_subnet_group_name,
         :description => db_subnet_group.db_subnet_group_description,
         :region      => region,
         :vpc         => vpc_name,
         :subnets     => subnet_names,
    }
  end

  def exists?
    Puppet.debug("Checking if rds db subnet #{name} exists in region #{target_region}")
    @property_hash[:ensure] == :present
  end

  def update
    Puppet.info("Updating RDS db subnet #{name} in region #{target_region}")
    subnets = resource[:subnets]
    desc = resource[:description]
    if ! subnets.nil?
      subnets = [subnets] unless subnets.is_a?(Array)
      modify_rds_subnet_group(resource[:region], name, subnets, desc)
    end
  end

  def create
    Puppet.info("Deploying RDS db subnet #{name} in region #{target_region}")
    subnets = subnet_ids_from_names(resource[:subnets] || [])
    config = {
        :db_subnet_group_name        => resource[:name],
        :db_subnet_group_description => resource[:description],
        :subnet_ids                  => subnets,
    }
    ## Validate that subnets do not live in same AZ fail.

    rds_client(resource[:region]).create_db_subnet_group(config)

    @property_hash[:ensure]  = :present
    @property_hash[:subnets] = subnets
  end

  def modify_rds_subnet_group(region, db_subnet_group_name, subnets, desc)
    subnet_ids = subnet_ids_from_names(subnets || [])
      rds_client(region).modify_db_subnet_group(
          db_subnet_group_name: db_subnet_group_name,
          subnet_ids: subnet_ids,
          db_subnet_group_description: desc
      )
  end

  def subnet_ids_from_names(names)
    unless names.empty?
      names = [names] unless names.is_a?(Array)
      response = ec2_client(resource[:region]).describe_subnets(filters: [
          {name: 'tag:Name', values: names}
      ])
      response.data.subnets.map(&:subnet_id)
    else
      []
    end
  end

  def flush
    update unless @property_hash[:ensure] == :absent
  end

  def destroy
    Puppet.info("Destroying rds db subnet #{name} in region #{target_region}")
    config = {
        db_subnet_group_name: name,
    }
    rds_client(resource[:region]).delete_db_subnet_group(config)
    @property_hash[:ensure] = :absent
  end

end
