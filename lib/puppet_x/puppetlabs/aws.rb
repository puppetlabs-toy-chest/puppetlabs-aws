module PuppetX
  module Puppetlabs
    # We purposefully inherit from Exception here due to PUP-3656
    # If we throw something based on StandardError prior to Puppet 4
    # the exception will prevent the prefetch, but the provider will
    # continue to run with incorrect data.
    class FetchingAWSDataError < Exception
      def initialize(region, type, message=nil)
        @message = message
        @region = region
        @type = type
      end

      def to_s
        """Puppet detected a problem with the information returned from AWS
when looking up #{@type} in #{@region}. The specific error was:

#{@message}

Rather than report on #{@type} resources in an inconsistent state we have exited.
This could be because some other process is modifying AWS at the same time."""
      end
    end

    class Aws < Puppet::Provider
      def self.regions
        if ENV['AWS_REGION'] and not ENV['AWS_REGION'].empty?
          [ENV['AWS_REGION']]
        elsif global_configuration and global_configuration['default'] and global_configuration['default']['region']
          [global_configuration['default']['region']]
        else
          ec2_client(default_region).describe_regions.data.regions.map(&:region_name)
        end
      end

      def regions
        self.class.regions
      end

      def self.default_region
        ENV['AWS_REGION'] || region_from_global_configuration || 'eu-west-1'
      end

      def default_region
        self.class.default_region
      end

      def target_region
        resource ? resource[:region] || region : region
      end

      def self.read_only(*methods)
        methods.each do |method|
          define_method("#{method}=") do |v|
            fail "#{method} property is read-only once #{resource.type} created."
          end
        end
      end

      def self.logger
        log_name = 'puppet-aws-debug.log'
        if global_configuration and global_configuration['default'] and global_configuration['default']['logger']
          Logger.new(log_name) if global_configuration['default']['logger'] == 'true'
        elsif ENV['PUPPET_AWS_DEBUG_LOG'] and not ENV['PUPPET_AWS_DEBUG_LOG'].empty?
          Logger.new(log_name)
        else
          nil
        end
      end

      def self.global_credentials
        # Under a Puppet agent we don't have the HOME environment variable available
        # so the standard way of detecting the location for the config file doesn't
        # work. The following provides a fall back method to a confdir config file.
        # The preference is still to use IAM instance roles if possible.
        begin
          Puppet.initialize_settings unless Puppet[:confdir]
          path = File.join(Puppet[:confdir], 'puppetlabs_aws_credentials.ini')
          credentials = ::Aws::SharedCredentials.new(path: path)
          credentials.loadable? ? credentials : nil
        rescue ::Aws::Errors::NoSuchProfileError
          nil
        end
      end

      def self.global_configuration
        Puppet.initialize_settings unless Puppet[:confdir]
        path = File.join(Puppet[:confdir], 'puppetlabs_aws_configuration.ini')
        File.exists?(path) ? ini_parse(File.new(path)) : nil
      end

      def self.region_from_global_configuration
        global_configuration['default']['region'] if global_configuration
      end

      def self.proxy_configuration
        if global_configuration and global_configuration['default'] and global_configuration['default']['http_proxy']
          global_configuration['default']['http_proxy']
        elsif ENV['PUPPET_AWS_PROXY'] and not ENV['PUPPET_AWS_PROXY'].empty?
          ENV['PUPPET_AWS_PROXY']
        else
          nil
        end
      end

      def self.client_config(region)
        config = {logger: logger}
        config[:http_proxy] = proxy_configuration if proxy_configuration
        config[:credentials] = global_credentials if global_credentials
        if global_configuration
          config[:region] = region_from_global_configuration || region
        else
          config[:region] = region
        end
        config
      end

      # This method is vendored from the AWS SDK, rather than including an
      # extra library just to parse an ini file
      def self.ini_parse(file)
        current_section = {}
        map = {}
        file.rewind
        file.each_line do |line|
          line = line.split(/^|\s;/).first # remove comments
          section = line.match(/^\s*\[([^\[\]]+)\]\s*$/) unless line.nil?
          if section
            current_section = section[1]
          elsif current_section
            item = line.match(/^\s*(.+?)\s*=\s*(.+?)\s*$/) unless line.nil?
            if item
              map[current_section] = map[current_section] || {}
              map[current_section][item[1]] = item[2]
            end
          end
        end
        map
      end

      def self.ec2_client(region = default_region)
        ::Aws::EC2::Client.new(client_config(region))
      end

      def ec2_client(region = default_region)
        self.class.ec2_client(region)
      end

      def vpc_only_account?
        response = ec2_client.describe_account_attributes(
          attribute_names: ['supported-platforms']
        )

        account_types = response.account_attributes.map(&:attribute_values).flatten.map(&:attribute_value)
        account_types == ['VPC']
      end

      def self.elb_client(region = default_region)
        ::Aws::ElasticLoadBalancing::Client.new(client_config(region))
      end

      def elb_client(region = default_region)
        self.class.elb_client(region)
      end

      def self.autoscaling_client(region = default_region)
        ::Aws::AutoScaling::Client.new(client_config(region))
      end

      def autoscaling_client(region = default_region)
        self.class.autoscaling_client(region)
      end

      def self.cloudwatch_client(region = default_region)
        ::Aws::CloudWatch::Client.new(client_config(region))
      end

      def cloudwatch_client(region = default_region)
        self.class.cloudwatch_client(region)
      end

      def self.route53_client(region = default_region)
        ::Aws::Route53::Client.new(client_config(region))
      end

      def route53_client(region = default_region)
        self.class.route53_client(region)
      end

      def rds_client(region = default_region)
        self.class.rds_client(region)
      end

      def self.rds_client(region = default_region)
        ::Aws::RDS::Client.new({region: region})
      end

      def sqs_client(region = default_region)
        self.class.sqs_client(region)
      end

      def self.sqs_client(region = default_region)
        ::Aws::SQS::Client.new({region: region})
      end


      def tags_for_resource
        tags = resource[:tags] ? resource[:tags].map { |k,v| {key: k, value: v} } : []
        tags << {key: 'Name', value: name}
      end

      def self.name_from_tag(item)
        name_tag = item.tags.detect { |tag| tag.key == 'Name' }
        name_tag ? name_tag.value : nil
      end

      def self.tags_for(item)
        tags = {}
        item.tags.each do |tag|
          tags[tag.key] = tag.value unless tag.key == 'Name'
        end
        tags
      end

      def tags=(value)
        Puppet.info("Updating tags for #{name} in region #{target_region}")
        ec2 = ec2_client(target_region)
        ec2.create_tags(
          resources: [@property_hash[:id]],
          tags: value.collect { |k,v| { :key => k, :value => v } }
        ) unless value.empty?
        missing_tags = tags.keys - value.keys
        ec2.delete_tags(
          resources: [@property_hash[:id]],
          tags: missing_tags.collect { |k| { :key => k } }
        ) unless missing_tags.empty?
      end

      def self.has_name?(hash)
        !hash[:name].nil? && !hash[:name].empty?
      end

      def self.vpc_name_from_id(region, vpc_id)
        @vpcs ||= name_cache_hash do |ec2, key|
          response = ec2.describe_vpcs(vpc_ids: [key])
          if response.data.vpcs.first.to_hash.keys.include?(:group_name)
            response.data.vpcs.first.group_name
          elsif response.data.vpcs.first.to_hash.keys.include?(:tags)
            name_from_tag(response.data.vpcs.first)
          end
        end
        @vpcs[[region, vpc_id]]
      end

      def self.security_group_name_from_id(region, group_id)
        @groups ||= name_cache_hash do |ec2, key|
          response = ec2.describe_security_groups(group_ids: [key])
          response.data.security_groups.first.group_name
        end
        @groups[[region, group_id]]
      end

      def self.customer_gateway_name_from_id(region, gateway_id)
        @customer_gateways ||= name_cache_hash do |ec2, key|
          response = ec2.describe_customer_gateways(customer_gateway_ids: [key])
          name_from_tag(response.data.customer_gateways.first)
        end

        @customer_gateways[[region, gateway_id]]
      end

      def self.vpn_gateway_name_from_id(region, gateway_id)
        @vpn_gateways ||= name_cache_hash do |ec2, key|
          response = ec2.describe_vpn_gateways(vpn_gateway_ids: [key])
          name_from_tag(response.data.vpn_gateways.first)
        end
        @vpn_gateways[[region, gateway_id]]
      end

      def self.options_name_from_id(region, options_id)
        @dhcp_options ||= name_cache_hash do |ec2, key|
          response = ec2.describe_dhcp_options(dhcp_options_ids: [key])
          name_from_tag(response.dhcp_options.first)
        end

        @dhcp_options[[region, options_id]]
      end

      def self.name_cache_hash(&block)
        Hash.new do |h, rk|
          region, key = rk
          h[key] = unless key.nil? || key.empty?
            block.call(ec2_client(region), key)
          else
            nil
          end
        end
      end

      def queue_url_from_name (queue_name )
        sqs = sqs_client(target_region)
        response = sqs.get_queue_url ({queue_name: name})
        response.data.queue_url
      end

      def self.gateway_name_from_id(region, gateway_id)
        ec2 = ec2_client(region)
        @gateways ||= Hash.new do |h, key|
          h[key] = if key == 'local'
            'local'
          elsif key
            begin
              igw_response = ec2.describe_internet_gateways(internet_gateway_ids: [key])
              name_from_tag(igw_response.data.internet_gateways.first)
            rescue ::Aws::EC2::Errors::InvalidInternetGatewayIDNotFound
              begin
                vgw_response = ec2.describe_vpn_gateways(vpn_gateway_ids: [key])
                name_from_tag(vgw_response.data.vpn_gateways.first)
              rescue ::Aws::EC2::Errors::InvalidVpnGatewayIDNotFound
                nil
              end
            end
          else
            nil
          end
        end
        @gateways[gateway_id]
      end

    end
  end
end
