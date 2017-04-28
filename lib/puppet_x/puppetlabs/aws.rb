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
            Puppet.warning "#{method} property is read-only once #{resource.type} created."
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

      def self.elbv2_client(region = default_region)
        ::Aws::ElasticLoadBalancingV2::Client.new(client_config(region))
      end

      def elbv2_client(region = default_region)
        self.class.elbv2_client(region)
      end

      def self.autoscaling_client(region = default_region)
        ::Aws::AutoScaling::Client.new(client_config(region))
      end

      def autoscaling_client(region = default_region)
        self.class.autoscaling_client(region)
      end

      def self.cloudformation_client(region = default_region)
        ::Aws::CloudFormation::Client.new(client_config(region))
      end

      def cloudformation_client(region = default_region)
        self.class.cloudformation_client(region)
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
        ::Aws::RDS::Client.new(client_config(region))
      end

      def sqs_client(region = default_region)
        self.class.sqs_client(region)
      end

      def self.sqs_client(region = default_region)
        ::Aws::SQS::Client.new(client_config(region))
      end

      def self.iam_client(region = default_region)
        ::Aws::IAM::Client.new(client_config(region))
      end

      def iam_client(region = default_region)
        self.class.iam_client(region)
      end

      def self.kms_client(region = default_region)
        ::Aws::KMS::Client.new(client_config(region))
      end

      def kms_client(region = default_region)
        self.class.kms_client(region)
      end

      def self.s3_client(region = default_region)
        ::Aws::S3::Client.new(client_config(region))
      end

      def s3_client(region = default_region)
        self.class.s3_client(region)
      end

      def self.ecs_client(region = default_region)
        ::Aws::ECS::Client.new(client_config(region))
      end

      def ecs_client(region = default_region)
        self.class.ecs_client(region)
      end

      def self.cloudfront_client(region = default_region)
        ::Aws::CloudFront::Client.new(client_config(region))
      end

      def cloudfront_client(region = default_region)
        self.class.cloudfront_client(region)
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

      def rds_tags=(value)
        Puppet.info("Updating RDS tags for #{name} in region #{target_region}")
        rds = rds_client(target_region)
        rds.add_tags_to_resource(
          resource_name: @property_hash[:arn],
          tags: value.collect { |k,v| { :key => k, :value => v } }
        ) unless value.empty?
        missing_tags = rds_tags.keys - value.keys
        rds.remove_tags_from_resource(
          resource_name: @property_hash[:arn],
          tag_keys: missing_tags.collect { |k| { :key => k } }
        ) unless missing_tags.empty?
      end

      def self.has_name?(hash)
        !hash[:name].nil? && !hash[:name].empty?
      end

      # Set up @vpcs. Always call this method before using @vpcs. @vpcs[region]
      # keeps track of VPC IDs => names discovered per region, to prevent
      # duplicate API calls.
      def self.init_vpcs(region)
        @vpcs ||= {}
        @vpcs[region] ||= {}
      end

      def self.vpc_id_from_name(region, vpc_name)
        self.init_vpcs(region)

        unless @vpcs[region].key(vpc_name)
          vpc_info = ec2_client(region).describe_vpcs(filters: [
            {
              name: 'tag-key',
              values: ['Name'],
            },
            {
              name: 'tag-value',
              values: [vpc_name],
            },
          ])

          return nil if vpc_info.vpcs.empty?

          vpc_id = vpc_info.vpcs.first['vpc_id']
          @vpcs[region][vpc_id] = vpc_name
        end

        @vpcs[region].key(vpc_name)
      end

      def self.vpc_name_from_id(region, vpc_id)
        self.init_vpcs(region)

        # Duplicate API calls will be made for unnamed VPCs, since they are
        # saved with the name nil.
        unless @vpcs[region][vpc_id]
          response = ec2_client(region).describe_vpcs(vpc_ids: [vpc_id])
          @vpcs[region][vpc_id] =
            if response.data.vpcs.first.to_hash.keys.include?(:group_name)
              response.data.vpcs.first.group_name
            elsif response.data.vpcs.first.to_hash.keys.include?(:tags)
              name_from_tag(response.data.vpcs.first)
            end
        end

        @vpcs[region][vpc_id]
      end

      # Set up the @ec2_instances.  Always call this method before using
      # @security_groups. @security_groups[region] keeps track of security
      # group IDs => names discovered per region, to prevent duplicate API
      # calls.
      def self.init_ec2_instances(region)
        @ec2_instances ||= {}
        @ec2_instances[region] ||= {}
      end

      def self.ec2_instance_id_from_name(region, instance_name)
        self.ec2_instance_ids_from_names(region, [instance_name]).first
      end

      def self.ec2_instance_ids_from_names(region, instance_names)
        self.init_ec2_instances(region)

        instance_names_to_discover = []
        instance_names.each do |instance_name|
          next if @ec2_instances[region].has_value?(instance_name)
          instance_names_to_discover << instance_name
        end

        unless instance_names_to_discover.empty?
          Puppet.debug("Calling ec2_client to resolve instances: #{instance_names_to_discover}")

          instance_info = ec2_client(region).describe_isntances(filters: [{
            name: 'tag:Name',
            values: instance_names_to_discover,
          }])

          # TODO Check if we have next_token on the response

          instance_info.each do |response|
            response.data.reservations.each do |reservation|
              reservation.instances.each do |instance|
                instance_name_tag = instance.tags.detect { |tag| tag.key == 'Name' }
                if instance_name_tag
                  @ec2_instances[region][instance.instance_id]= instance_name_tag.value
                end
              end
            end
          end
        end

        instance_names.collect do |instance_name|
          @security_groups[region].key(instance_name)
        end.compact
      end

      def self.ec2_instance_name_from_id(region, instance_id)
        self.ec2_instance_names_from_ids(region, [instance_id]).first
      end

      def self.ec2_instance_names_from_ids(region, instance_ids)
        self.init_ec2_instances(region)

        instance_ids_to_discover = []
        instance_ids.each do |instance_id|
          next if @ec2_instances[region].has_key?(instance_id)
          instance_ids_to_discover << instance_id
        end

        unless instance_ids_to_discover.empty?
          Puppet.debug("Calling ec2_client to resolve instances: #{instance_ids_to_discover}")
          instance_info = ec2_client(region).describe_instances(instance_ids: instance_ids_to_discover)

          # TODO Check if we have next_token on the response

          instance_info.each do |response|
            response.data.reservations.each do |reservation|
              reservation.instances.each do |instance|
                instance_name_tag = instance.tags.detect { |tag| tag.key == 'Name' }
                if instance_name_tag
                  @ec2_instances[region][instance.instance_id]= instance_name_tag.value
                end
              end
            end
          end
        end

        instance_ids.collect do |instance_id|
          @ec2_instances[region][instance_id]
        end.compact
      end

      # Set up @security_groups. Always call this method before using
      # @security_groups. @security_groups[region] keeps track of security
      # group IDs => names discovered per region, to prevent duplicate API
      # calls.
      def self.init_security_groups(region)
        @security_groups ||= {}
        @security_groups[region] ||= {}
      end

      def self.security_group_id_from_name(region, sg_name)
        self.security_group_ids_from_names(region, [sg_name]).first
      end

      def self.security_group_ids_from_names(region, sg_names)
        self.init_security_groups(region)

        sg_names_to_discover = []
        sg_names.each do |sg_name|
          next if @security_groups[region].has_value?(sg_name)
          sg_names_to_discover << sg_name
        end

        unless sg_names_to_discover.empty?
          Puppet.debug("Calling ec2_client to resolve security_groups: #{sg_names_to_discover}")
          sg_info = ec2_client(region).describe_security_groups(filters: [{
            name: 'group-name',
            values: sg_names_to_discover,
          }])

          sg_info.security_groups.each do |sg|
            @security_groups[region][sg.group_id] = sg.group_name
          end
        end

        sg_names.collect do |sg_name|
          @security_groups[region].key(sg_name)
        end.compact
      end

      def self.security_group_name_from_id(region, sg_id)
        self.security_group_names_from_ids(region, [sg_id]).first
      end

      def self.security_group_names_from_ids(region, sg_ids)
        self.init_security_groups(region)

        sg_ids_to_discover = []
        sg_ids.each do |sg_id|
          sg_ids_to_discover << sg_id unless @security_groups[region].has_key?(sg_id)
        end

        unless sg_ids_to_discover.empty?
          Puppet.debug("Calling ec2_client to resolve security_groups: #{sg_ids_to_discover}")
          sg_info = ec2_client(region).describe_security_groups(group_ids: sg_ids_to_discover)

          sg_info.security_groups.each do |sg|
            @security_groups[region][sg.group_id] = sg.group_name
          end
        end

        sg_ids.collect do |sg_id|
          @security_groups[region][sg_id]
        end.compact
      end

      # Set up @subnets. Always call this method before using @subnets.
      # @subnets[region] keeps track of subnet IDs => names discovered per
      # region, to prevent duplicate API calls.
      def self.init_subnets(region)
        @subnets ||= {}
        @subnets[region] ||= {}
      end

      def self.subnet_id_from_name(region, subnet_name)
        self.subnet_ids_from_names(region, [subnet_name]).first
      end

      def self.subnet_ids_from_names(region, subnet_names)
        self.init_subnets(region)

        subnet_names_to_discover = []
        subnet_names.each do |subnet_name|
          next if @subnets[region].has_value?(subnet_name)
          subnet_names_to_discover << subnet_name
        end

        unless subnet_names_to_discover.empty?
          Puppet.debug("Calling ec2_client to resolve subnets: #{subnet_names_to_discover}")
          subnet_info = ec2_client(region).describe_subnets(filters: [{
            name: 'tag:Name',
            value: subnet_names_to_discover
          }])

          subnet_info.subnets.each do |subnet|
            subnet_name_tag = subnet.tags.detect { |tag| tag.key == 'Name' }
            if subnet_name_tag
              @subnets[region][subnet.subnet_id] = subnet_name_tag.value
            end
          end
        end

        subnet_names.collect do |subnet_name|
          @security_groups[region].key(subnet_name)
        end.compact
      end

      def self.subnet_name_from_id(region, subnet_id)
        self.subnet_names_from_ids(region, [subnet_id]).first
      end

      def self.subnet_names_from_ids(region, subnet_ids)
        self.init_subnets(region)

        subnet_ids_to_discover = []
        subnet_ids.each do |subnet_id|
          next if @subnets[region].has_key?(subnet_id)
          subnet_ids_to_discover << subnet_id
        end

        unless subnet_ids_to_discover.empty?
          Puppet.debug("Calling ec2_client to resolve subnets: #{subnet_ids_to_discover}")
          subnet_info = ec2_client(region).describe_subnets(
            subnet_ids: subnet_ids_to_discover
          )

          subnet_info.subnets.each do |subnet|
            subnet_name_tag = subnet.tags.detect { |tag| tag.key == 'Name' }
            if subnet_name_tag
              @subnets[region][subnet.subnet_id] = subnet_name_tag.value
            end
          end
        end

        subnet_ids.collect do |subnet_id|
          @subnets[region][subnet_id]
        end.compact
      end


      ####

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

      def queue_url_from_name(queue_name )
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

      def self.normalize_hash(hash)
        # Sort and format the received hash for simpler comparison.
        #
        # Symbolized keys are converted to string'd keys.  Values are sent to the
        # normalize_values method for processing.  Returns a hash sorted by keys.
        #
        data = {}

        fail "Invalid data type when attempting normalize of hash: #{hash.class}" unless hash.is_a? Hash

        hash.keys.sort_by{|k|k.to_s}.each {|k|
          value = hash[k]
          data[k.to_s] = self.normalize_values(value)
        }
        sorted_hash = {}
        data.keys.sort.each {|k|
          sorted_hash[k] = data[k]
        }
        sorted_hash
      end

      def self.normalize_values(value)
        # Convert the received value data into a standard format for simpler
        # comparison.
        #
        # This results in the conversion of boolean strings to booleans, string
        # integers to integers, etc.  Array values are recursively normalized.
        # Hash values are normalized using the normalize_hash method.
        #
        if value.is_a? String
          return true if value == 'true'
          return false if value == 'false'

          begin
            return Integer(value)
          rescue ArgumentError
            return value
          end

        elsif value.is_a? true.class or value.is_a? false.class
          return value
        elsif value.is_a? Numeric
          return value
        elsif value.is_a? Symbol
          return value.to_s
        elsif value.is_a? Hash
          return self.normalize_hash(value)
        elsif value.is_a? Array
          value_class_list = value.map(&:class).uniq

          return [] unless value.size > 0

          if value_class_list.include? String
            return value.sort
          elsif value_class_list.include? Hash
            value_list = value
          else
            value_list = value
          end

          #return nil if value.size == 0
          results = value_list.map {|v|
            self.normalize_values(v)
          }

          results_class_list = results.map(&:class).uniq
          if results_class_list.include? Hash
            nested_results__value_class_list = results.collect {|i|
              i.collect {|k,v|
                v.class
              }
            }.flatten.uniq

            # If we've got a nestd hash, this sorting will fail
            unless nested_results__value_class_list.include? Hash
              results = results.sort_by{|k|
                k.flatten
              }
            end
          end
          return results
        else
          Puppet.debug("Value class #{value.class} not handled")
        end
      end

    end
  end
end
