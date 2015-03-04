require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:rds_db_parameter_group).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    regions.collect do |region|
      instances = []
      rds_client(region).describe_db_parameter_groups.each do |response|
        response.data.db_parameter_groups.each do |db_parameter_group|
          # There's always a default class
          hash = db_parameter_group_to_hash(region, db_parameter_group)
          instances << new(hash) if hash[:name]
        end
      end
      instances
    end.flatten
  end

  def self.db_parameter_group_to_hash(region, db_parameter_group)
    {
      :name => db_parameter_group.db_parameter_group_name,
      :description => db_parameter_group.description,
      :family => db_parameter_group.db_parameter_group_family,
      :region => region,
    }
  end

end
