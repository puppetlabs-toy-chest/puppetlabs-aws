require 'aws-sdk-core'

module PuppetX
  module Puppetlabs
    class Aws < Puppet::Provider
      def self.regions
        if ENV['AWS_REGION'] and not ENV['AWS_REGION'].empty?
          [ENV['AWS_REGION']]
        else
          ec2_client(default_region).describe_regions.data.regions.map(&:region_name)
        end
      end

      def regions
        self.class.regions
      end

      def self.default_region
        ENV['AWS_REGION'] || 'eu-west-1'
      end

      def default_region
        self.class.default_region
      end

      def self.read_only(*methods)
        methods.each do |method|
          define_method("#{method}=") do |v|
            fail "#{method} property is read-only once #{resource.type} created."
          end
        end
      end

      def self.ec2_client(region = default_region)
        ::Aws::EC2::Client.new({region: region})
      end

      def ec2_client(region = default_region)
        self.class.ec2_client(region)
      end

      def vpc_only_account?
        # this is a stub for detecting VPC only accounts
        # it currently maintains the existing functionality
        false
      end

      def self.elb_client(region = default_region)
        ::Aws::ElasticLoadBalancing::Client.new({region: region})
      end

      def elb_client(region = default_region)
        self.class.elb_client(region)
      end

      def self.autoscaling_client(region = default_region)
        ::Aws::AutoScaling::Client.new({region: region})
      end

      def autoscaling_client(region = default_region)
        self.class.autoscaling_client(region)
      end

      def self.cloudwatch_client(region = default_region)
        ::Aws::CloudWatch::Client.new({region: region})
      end

      def cloudwatch_client(region = default_region)
        self.class.cloudwatch_client(region)
      end

      def self.route53_client(region = default_region)
        ::Aws::Route53::Client.new({region: region})
      end

      def route53_client(region = default_region)
        self.class.route53_client(region)
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
        Puppet.info("Updating tags for #{name} in region #{region}")
        ec2 = ec2_client(resource[:region])
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

    end
  end
end
