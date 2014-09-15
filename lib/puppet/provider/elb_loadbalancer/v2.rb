require 'aws-sdk-core'
require 'pry'

require_relative '../../../puppet_x/puppetlabs/aws.rb'

module Puppet
  class Provider
    class ElbLoadbalancer < Puppet::Provider
      def initialize(*args)
        @elb_client = PuppetX::Puppetlabs::Aws.elb_client
        @ec2_client = PuppetX::Puppetlabs::Aws.ec2_client
        super(*args)
      end

      def exists?
        Puppet.info("Checking if load balancer #{name} exists")
        @elb_client.describe_load_balancers(
          load_balancer_names: [name]
        )
        true
      rescue Aws::ElasticLoadBalancing::Errors::LoadBalancerNotFound
        false
      end

      def create
        Puppet.info("Creating load balancer #{name}")
        groups = resource[:security_groups]
        groups = [groups] unless groups.is_a?(Array)

        response = @ec2_client.describe_security_groups(group_names: groups.map(&:title))

        zones = resource[:availability_zones]
        zones = [zones] unless zones.is_a?(Array)

        @elb_client.create_load_balancer(
          load_balancer_name: name,
          listeners: [
            {
              protocol: 'tcp',
              load_balancer_port: 80,
              instance_protocol: 'tcp',
              instance_port: 80,
            },
          ],
          availability_zones: zones,
          security_groups: response.data.security_groups.map(&:group_id)
        )

        instances = resource[:instances]
        instances = [instances] unless groups.is_a?(Array)

        response = @ec2_client.describe_instances(
          filters: [
            {name: 'tag:Name', values: instances.map(&:title)},
            {name: 'instance-state-name', values: ['pending', 'running']}
          ]
        )

        instance_ids = response.reservations.map(&:instances).
          flatten.map(&:instance_id)

        instance_input = []
        instance_ids.each do |id|
          instance_input << { instance_id: id }
        end

        @elb_client.register_instances_with_load_balancer(
          load_balancer_name: name,
          instances: instance_input
        )
      end

      def destroy
        Puppet.info("Destroying load balancer #{name}")
        @elb_client.delete_load_balancer(
          load_balancer_name: name,
        )
      end
    end
  end
end

Puppet::Type.type(:elb_loadbalancer).provide(:v2,
  parent: Puppet::Provider::ElbLoadbalancer) do
    confine feature: :aws
end
