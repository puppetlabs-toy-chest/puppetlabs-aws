require 'aws-sdk-core'

module PuppetX
  module Puppetlabs
    class Aws < Puppet::Provider
      def self.regions
        if ENV['AWS_REGION'] and not ENV['AWS_REGION'].empty?
          [ENV['AWS_REGION']]
        else
          ec2_client(region: default_region).describe_regions.data.regions.map(&:region_name)
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

      def self.ec2_client(region: default_region)
        ::Aws::EC2::Client.new(region: region)
      end

      def ec2_client(region: default_region)
        self.class.ec2_client(region: region)
      end

      def self.elb_client(region: default_region)
        ::Aws::ElasticLoadBalancing::Client.new(region: region)
      end

      def elb_client(region: default_region)
        self.class.elb_client(region: region)
      end
    end
  end
end
