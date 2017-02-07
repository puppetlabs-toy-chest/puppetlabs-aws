require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:rds_db_option_group).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    regions.collect do |region|
      instances = []
      rds_client(region).describe_option_groups.each do |response|
        response.data.option_groups_list.each do |db_option_group|
          # There's always a default class
          hash = db_option_group_to_hash(region, db_option_group)
          instances << new(hash) if hash[:name]
        end
      end
      instances
    end.flatten
  end

  def self.db_option_group_to_hash(region, db_option_group)
    {
      :name => db_option_group.option_group_name,
      :description => db_option_group.option_group_description,
      :region => region,
    }
  end

end
