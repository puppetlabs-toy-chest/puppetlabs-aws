require 'aws-sdk-core'

module PuppetX
  module Puppetlabs
    class Aws
      def self.logger
        Logger.new('logfile.log')
      end
      def self.ec2_client(region: 'us-west-1')
        ::Aws::EC2::Client.new(
          region: region,
          logger: self.logger,
          http_wire_trace: true
        )
      end
      def self.elb_client(region: 'us-west-1')
        ::Aws::ElasticLoadBalancing::Client.new(
          region: region,
          logger: self.logger,
          http_wire_trace: true
        )
      end
    end
  end
end
