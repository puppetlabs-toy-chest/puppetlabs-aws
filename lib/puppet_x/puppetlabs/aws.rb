require 'aws-sdk-core'

module PuppetX
  module Puppetlabs
    class Aws < Puppet::Provider
      def self.regions
        ec2_client(region: 'sa-east-1').describe_regions.data.regions.map(&:region_name)
      end

      def regions
        self.class.regions
      end

      def self.ec2_client(region: nil)
        ::Aws::EC2::Client.new(region: region)
      end

      def ec2_client(region: nil)
        self.class.ec2_client(region: region)
      end

      def self.elb_client(region: nil)
        ::Aws::ElasticLoadBalancing::Client.new(region: region)
      end

      def elb_client(region: nil)
        self.class.elb_client(region: region)
      end
    end
  end
end
