require_relative '../../puppet_x/puppetlabs/aws.rb'

module PuppetX
  module Puppetlabs
    module Iam_policy
      def self.get_policies
        # Handles enumeration of all policies
        policy_results = PuppetX::Puppetlabs::Aws.iam_client.list_policies()
        policies = policy_results.policies

        truncated = policy_results.is_truncated
        marker = policy_results.marker
        while truncated and marker
          Puppet.debug('Results truncated, proceeding with discovery')
          response = PuppetX::Puppetlabs::Aws.iam_client.list_policies({marker: marker})
          response.policies.each {|p|
            policies << p
          }

          truncated = response.is_truncated
          marker = response.marker
        end

        policies
      end
    end
  end
end
