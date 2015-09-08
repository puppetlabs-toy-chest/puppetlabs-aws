require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:rds_db_securitygroup).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    regions.collect do |region|
      instances = []
      rds_client(region).describe_db_security_groups.each do |response|
        response.data.db_security_groups.each do |db_security_group|
          # There's always a default class
          unless db_security_group.db_security_group_name =~ /^default$/
            hash = db_security_group_to_hash(region, db_security_group)
            instances << new(hash) if hash[:name]
          end
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

  read_only(:region, :description)

  def self.db_security_group_to_hash(region, db_security_group)
    {
      :ensure => :present,
      :region => region,
      :name => db_security_group.db_security_group_name,
      :description => db_security_group.db_security_group_description,
      :owner_id => db_security_group.owner_id,
      :security_groups => ec2_security_group_to_array_of_hashes(db_security_group.ec2_security_groups),
      :ip_ranges => ip_ranges_to_array_of_hashes(db_security_group.ip_ranges),
    }
  end

  def exists?
    Puppet.info("Checking if DB Security Group #{name} exists")
    [:present, :creating, :available].include? @property_hash[:ensure]
  end

  def create
    Puppet.info("Creating DB Security Group #{name}")
    config = {
      :db_security_group_name        => resource[:name],
      :db_security_group_description => resource[:description],
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
    rds.delete_db_security_group(config)
    @property_hash[:ensure] = :absent
  end

  def self.ec2_security_group_to_array_of_hashes(ec2_security_groups)
    ec2_security_groups.collect do |group|
      {
        :status => group.status,
        :ec2_security_group_name => group.ec2_security_group_name,
        :ec2_security_group_owner_id => group.ec2_security_group_owner_id,
        :ec2_security_group_id => group.ec2_security_group_id,
      }
    end
  end

  def self.ip_ranges_to_array_of_hashes(ip_ranges)
    ip_ranges.collect do |group|
      {
        :status => group.status,
        :ip_range => group.cidrip,
      }
    end
  end

end
