require 'aws-sdk-core'

module Puppet
  class Provider
    class Ec2Instance < Puppet::Provider
      def initialize(*args)
        super(*args)
      end

      def exists?
        Puppet.debug("Checking if instance #{resource[:name]} exists")
      end

      def create
      end

      def destroy
      end
    end
  end
end

Puppet::Type.type(:ec2_instance).provide(:v2,
  parent: Puppet::Provider::Ec2Instance) do
    confine feature: :aws
end
