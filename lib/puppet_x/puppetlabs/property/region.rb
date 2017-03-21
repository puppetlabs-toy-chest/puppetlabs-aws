module PuppetX
  module Property
    class AwsRegion < Puppet::Property
      validate do |value|
        name = resource[:name]
        fail 'region should be a String' unless value.is_a?(String)
        fail 'region should be a valid AWS region' unless value =~ /^([a-z]{2}-[a-z]{4,}-\d)$/
        if ENV['AWS_REGION'] && ENV['AWS_REGION'] != value
          fail "if using AWS_REGION environment variable it must match the specified region value for #{name}"
        end
      end
    end
  end
end
