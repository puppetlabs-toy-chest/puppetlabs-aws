#!/usr/bin/env ruby

require 'aws-sdk-core'
require 'clamp'

Clamp do

  option '--region', 'REGION', 'AWS Region in which to look for instances', :environment_variable => 'AWS_REGION'
  option '--tag', 'NAME:VALUE', 'Filter instances by tag', :multivalued => true

  def execute

    signal_usage_error 'You must specify a region' unless region

    tag_list.each do |tag|
      signal_usage_error 'Tags must take the form NAME:VALUE' unless tag =~ /[a-zA-Z_-]+:[a-zA-Z_-]/
    end

    client = Aws::EC2::Client.new(region: region)

    filters = [
      {name: 'instance-state-name', values: ['running']}
    ]

    tags = tag_list.map { |tag| tag.split(':') }
    tags.each do |name, value|
      filters << {name: "tag:#{name}", values: [value]}
    end

    begin
      response = client.describe_instances(filters: filters)
    rescue Seahorse::Client::Http::Error
      signal_usage_error 'You must specify a valid region'
    end

    instances = response.data.reservations.collect do |reservation|
      reservation.instances.collect do |instance|
        instance.public_dns_name
      end
    end

    puts instances
  end

end
