require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:elbv2_loadbalancer).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do

  confine feature: :aws

  mk_resource_methods

  def self.instances()
    Puppet.debug("Fetching ELBv2 Load Balancers (instances)")
    regions.collect do |region|
      vpc_names = {}
      vpc_response = ec2_client(region).describe_vpcs()
      vpc_response.data.vpcs.each do |vpc|
        vpc_name = name_from_tag(vpc)
        vpc_names[vpc.vpc_id] = vpc_name if vpc_name
      end

      tg_names = {}
      tg_response = elbv2_client(region).describe_target_groups()
      tg_response.data.target_groups.each do |tg|
        tg_names[tg.target_group_arn] = tg.target_group_name
      end

      cert_names = {}
      cert_response = iam_client(region).list_server_certificates()
      cert_response.data.server_certificate_metadata_list.each do |cert|
        cert_names[cert.arn] = cert.server_certificate_name
      end

      load_balancers = []
      elbs(region) do |elb|
        load_balancers << new(load_balancer_to_hash(region, elb, vpc_names, tg_names, cert_names) )
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

    Puppet.debug(response)

    response.load_balancers.each do |elb|
      yield elb
    end

    while marker
      response = region_client.describe_load_balancers( {
        marker: marker
      })
      marker = response.next_marker
      response.load_balancers.each do |elb|
        yield elb
      end
    end
  end

  def self.listeners(region,lbarn)
    Puppet.debug("listeners('#{region}','#{lbarn}')")
    region_client = elbv2_client(region)

    response = region_client.describe_listeners( {
      load_balancer_arn: lbarn,
    })
    marker = response.next_marker

    response.listeners.each do |listener|
      yield listener
    end

    while marker
      response = region_client.describe_listeners( {
        marker: marker
      })
      marker = response.next_marker
      response.listeners.each do |listener|
        yield listener
      end
    end
  end

  def self.rules(region,lstnrarn)
    Puppet.debug("rules('#{region}','#{lstnrarn}')")
    region_client = elbv2_client(region)

    response = region_client.describe_rules( {
      listener_arn: lstnrarn,
    })
    response.rules.each do |rule|
      next if rule.priority == 'default'
      yield rule
    end
  end

  def self.load_balancer_to_hash(region, elb, vpcs, tgs, certs)
    Puppet.debug("vpc id: #{elb.vpc_id}, Vpcs: #{vpcs}")

    elblisteners = [ ]
    listeners(region, elb.load_balancer_arn) do |listener|
      elblisteners << listener_to_hash(region, listener, tgs, certs)
    end

    Puppet.debug("Listeners: #{elblisteners}")

    attributes = { }
    tags = { }

    {
      ensure: :present,
      name: elb.load_balancer_name,
      arn:  elb.load_balancer_arn,
      region: region,
      vpc: vpcs[elb.vpc_id],
      scheme: elb.scheme,
      listeners: elblisteners,
      tags: tags,
    }
  end

  def self.listener_to_hash(region, listener, tgs, certs)
    Puppet.debug("listener_to_hash: #{listener}")

    rules = [ ]
    rules(region,listener.listener_arn) do |rule|
      rules << rule_to_hash(rule,tgs)
    end

    lstnr = {
      protocol: listener.protocol,
      port: listener.port,
      ssl_policy: listener.ssl_policy,
      default_target_group: tgs[ listener.default_actions.first.target_group_arn ],
    }
    lstnr[:rules] = rules unless rules.empty?
    lstnr[:certificate] = certs[listener.certificates.first.certificate_arn] unless listener.certificates.empty?

    lstnr
  end

  def self.rule_to_hash(rule,tgs)
    Puppet.debug("rule_to_hash: #{rule}")

    rh = {
      priority: rule.priority,
      target_group: tgs[rule.actions.first.target_group_arn],
    }

    rh[:path_match] = rule.conditions.first.values.first unless rule.conditions.empty?

    rh
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.debug("Creating load balancer #{name} in region #{target_region}")

    elbv2 = elbv2_client(target_region)
    ec2 = ec2_client(target_region)
    ec2_response = ec2.describe_subnets()

    config = {
      load_balancer_name: name,
      
      scheme: scheme.nil? ? scheme : :'internet-facing',
    }

  end

  def destroy
    Puppet.debug("Deleting load balancer #{name} in region #{target_region}")
    elbv2 = elbv2_client(target_region)

    Puppet.debug("Load Balancer Arn: ${@property_hash[:arn]}")

    elbv2.delete_load_balancer({
      load_balancer_arn: @property_hash[:arn],
    })
    @property_hash[:ensure] = :absent
  end
end
