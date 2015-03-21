module PuppetX
  module Property
    class AwsRegion < Puppet::Property
      validate do |value|
        name = resource[:name]
        fail "region for #{name} should not contains spaces" if value =~ /\s/
        if !ENV['AWS_REGION'].nil? && ENV['AWS_REGION'] != value
          fail "if using AWS_REGION environment variable it must match the specified region value for #{name}"
        end
      end
    end
  end
end
