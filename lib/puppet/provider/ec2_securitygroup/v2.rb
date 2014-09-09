require 'aws-sdk-core'
require 'retries'
require 'pry'

module Puppet
  class Provider
    class Ec2Securitygroup < Puppet::Provider
      def initialize(*args)
        @client = Aws::EC2::Client.new(region: 'us-west-2')
        super(*args)
      end

      def exists?
        @client.describe_security_groups(group_names: [name])
        Puppet.info("Security group #{name} exists")
        true
      rescue Aws::EC2::Errors::InvalidGroupNotFound
        Puppet.info("Security group #{name} doesn't exist")
        false
      end

      def create
        Puppet.info("Creating security group #{name}")
        @client.create_security_group(
          group_name: name,
          description: resource[:description]
        )

        rules = resource[:ingress]
        rules = [rules] unless rules.is_a?(Array)

        rules.each do |rule|
          if rule.key? 'source'
            @client.authorize_security_group_ingress(
              group_name: name,
              source_security_group_name: rule[:source].title
            )
          else
            @client.authorize_security_group_ingress(
              group_name: name,
              ip_permissions: [{
                ip_protocol: rule[:protocol],
                to_port: rule[:port].to_i,
                from_port: rule[:port].to_i,
                ip_ranges: [{
                  cidr_ip: rule[:cidr]
                }]
              }]
            )
          end
        end
      end

      def destroy
        Puppet.info("Deleting security group #{name}")
        @client.delete_security_group(
          group_name: name
        )
      end
    end
  end
end

Puppet::Type.type(:ec2_securitygroup).provide(
  :v2,
  parent: Puppet::Provider::Ec2Securitygroup) do
    confine feature: :aws
    confine feature: :retries
  end
