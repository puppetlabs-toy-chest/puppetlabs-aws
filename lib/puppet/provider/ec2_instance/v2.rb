require 'aws-sdk-core'

module Puppet
  class Provider
    class Ec2Instance < Puppet::Provider
      def initialize(*args)
        @client = Aws::EC2::Client.new(region: 'us-west-2')
        super(*args)
      end

      def _find_instances
        @client.describe_instances(filters: [
          {name: 'tag:Name', values: [name]},
          {name: 'instance-state-name', values: ['pending', 'running']}
        ])
      end

      def exists?
        Puppet.info("Checking if instance #{name} exists")
        !_find_instances.reservations.empty?
      end

      def create
        Puppet.info("Creating instance #{name}")
        groups = resource[:security_groups]
        groups = [groups] unless groups.is_a?(Array)
        response = @client.run_instances(
          image_id: resource[:image_id],
          min_count: 1,
          max_count: 1,
          security_groups: groups.map(&:title),
          instance_type: resource[:instance_type],
        )
        @client.create_tags(
          resources: response.instances.map(&:instance_id),
          tags: [
            {key: 'Name', value: name}
          ]
        )
      end

      def destroy
        Puppet.info("Deleting instance #{name}")
        @client.terminate_instances(
          instance_ids: _find_instances.reservations.first.instances.map(&:instance_id),
        )
      end
    end
  end
end

Puppet::Type.type(:ec2_instance).provide(:v2,
  parent: Puppet::Provider::Ec2Instance) do
    confine feature: :aws
end
