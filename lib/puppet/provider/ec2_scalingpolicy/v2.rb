require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:ec2_scalingpolicy).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    regions.collect do |region|
      begin
        policies = []
        autoscaling_client(region).describe_policies.each do |response|
          response.data.scaling_policies.each do |policy|
            hash = policy_to_hash(region, policy)
            policies << new(hash)
          end
        end
        policies
      rescue Timeout::Error, StandardError => e
        raise PuppetX::Puppetlabs::FetchingAWSDataError.new(region, self.resource_type.name.to_s, e.message)
      end
    end.flatten
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region
      end
    end
  end

  read_only(:region, :auto_scaling_group)

  def self.policy_to_hash(region, policy)
    {
      name: policy.policy_name,
      scaling_adjustment: policy.scaling_adjustment,
      adjustment_type: policy.adjustment_type,
      auto_scaling_group: policy.auto_scaling_group_name,
      ensure: :present,
      region: region
    }
  end

  def exists?
    Puppet.debug("Checking if scaling policy #{name} exists in region #{target_region}")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating scaling policy #{name} in region #{target_region}")
    update
    @property_hash[:ensure] = :present
  end

  def update
    autoscaling_client(target_region).put_scaling_policy(
      policy_name: name,
      auto_scaling_group_name: resource[:auto_scaling_group],
      scaling_adjustment: resource[:scaling_adjustment],
      adjustment_type: resource[:adjustment_type],
    )
  end

  def flush
    update unless @property_hash[:ensure] == :absent
  end

  def destroy
    Puppet.info("Deleting scaling policy #{name} in region #{target_region}")
    autoscaling_client(target_region).delete_policy(
      auto_scaling_group_name: resource[:auto_scaling_group],
      policy_name: name,
    )
    @property_hash[:ensure] = :absent
  end
end
