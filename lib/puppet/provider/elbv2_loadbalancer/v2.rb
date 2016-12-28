require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:elbv2_loadbalancer).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do

  confine feature: :aws

  mk_resource_methods

  def self.instances()
    Puppet.debug('Fetching ELBv2 Load Balancers (instances)')
    regions.collect do |region|
      vpc_names = {}
      vpc_response = ec2_client(region).describe_vpcs()
      vpc_response.data.vpcs.each do |vpc|
        vpc_name = name_from_tag(vpc)
        vpc_names[vpc.vpc_id] = vpc_name if vpc_name
      end
      target_groups = []
      elbs(region) do |elb|
        load_balancers << new(load_balancer_to_hash(region, elb, vpc_names) )
      end

      load_balancers
    end.flatten
  end

  def self.prefetch(resources)
    instances.each do |prov|
      Puppet.debug("Prefetching #{prov.name}")
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        if resource[:region] == prov.region
          Puppet.debug("Updating resource for #{prov.name}")
          resource.provider = prov
        end
      end
    end
  end

  def self.elbs(region)
    region_client = elbv2_client(region)

    response = region_client.describe_load_balancers()
    marker = response.next_marker

    response.load_balancer_descriptions.each do |elb|
      yield elb
    end

    while marker
      response = region_client.describe_load_balancers( {
        marker: marker
      })
      marker = response.next_marker
      response.load_balancer_descriptions.each do |elb|
        yield elb
      end
    end
  end

  def self.load_balancer_to_hash(region, elb, vpcs)
    attributes = { }
    tags = { }
    {
      name: elb.load_balancer_name,
      arn:  elb.load_balancer_arn,
      region: region,
      vpc: vpcs[target_group.vpc_id],
      tags: tags,
    }
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.debug("Creating load balancer #{name} in region #{target_region}")

  end

  def destroy
    Puppet.debug("Deleting load balancer #{name} in region #{target_region}")
    elbv2 = elbv2_client(target_region)
  end
end
