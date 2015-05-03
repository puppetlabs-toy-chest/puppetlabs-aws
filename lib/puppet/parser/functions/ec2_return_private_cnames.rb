require_relative '../../../puppet_x/puppetlabs/aws.rb'
require 'aws-sdk-core'

module Puppet::Parser::Functions
  newfunction(:ec2_return_private_cnames, :type => :rvalue) do |args|
    func_name = __method__.to_s.sub!('real_function_','')
    method = :private_dns_name

    unless args.length == 3 then
      raise Puppet::ParseError, ("#{func_name}(): wrong number of arguments (#{args.length}; must be 3)")
    end

    region    = args[0]
    instances = args[1]
    subnet_id = args[2]

    instances = [instances] if instances.instance_of?(String)
    subnet_id = [subnet_id] if subnet_id.instance_of?(String)

    instances.reject!(&:empty?)
    subnet_id.reject!(&:empty?)

    unless region.instance_of?(String) then
      raise Puppet::ParseError, ("#{func_name}(): Parameter [region] is not a string.  It looks to be a #{filter.class}")
    end

    unless instances.instance_of?(Array) and not instances.empty? and instances.all? {|element| element.instance_of?(String)} then
      raise Puppet::ParseError, ("#{func_name}(): Parameter [filter] must be an array containing only strings, with at least one search filter.")
    end

    unless subnet_id.instance_of?(Array) and subnet_id.all? {|element| element.instance_of?(String)} then
      raise Puppet::ParseError, ("#{func_name}(): Parameter [subnet_id] must be an array containing strings.")
    end

    filter = [{
              name: 'tag:Name',
              values: instances
             }]

    response = PuppetX::Puppetlabs::Aws.ec2_client(region).describe_instances(filters: filter)
    values = Array.new

    response.reservations.each do |reservation|
      reservation.instances.each do |instance|
        instance.network_interfaces.each do |interface|
          values << interface[method] if subnet_id.empty? or subnet_id.include? interface.subnet_id
        end
      end
    end
    values.flatten.compact
  end
end
