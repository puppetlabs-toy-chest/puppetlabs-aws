require 'aws-sdk-core'

module PuppetX
  module Puppetlabs
    class Aws
      def self.ec2_client
        ::Aws::EC2::Client.new(
          region: 'us-west-2',
          logger: Logger.new('logfile.log'),
          http_wire_trace: true
        )
      end
      def self.elb_client
        ::Aws::ElasticLoadBalancing::Client.new(
          region: 'us-west-2',
          logger: Logger.new('logfile.log'),
          http_wire_trace: true
        )
      end
    end
  end
end
