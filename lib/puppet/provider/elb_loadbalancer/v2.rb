require 'aws-sdk-core'

module Puppet
  class Provider
    class ElbLoadbalancer < Puppet::Provider
      def initialize(*args)
        super(*args)
      end

      def exists?
        Puppet.debug("Checking if load balancer #{resource[:name]} exists")
      end

      def create
      end

      def destroy
      end
    end
  end
end

Puppet::Type.type(:elb_loadbalancer).provide(:v2,
  parent: Puppet::Provider::ElbLoadbalancer) do
    confine feature: :aws
end
