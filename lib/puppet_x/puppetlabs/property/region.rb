module PuppetX
  module Property
    class AwsRegion < Puppet::Property
      validate do |value|
        name = resource[:name]
        fail 'region should not contain spaces' if value =~ /\s/
        fail 'region should not be blank' if value == ''
        fail 'region should be a String' unless value.is_a?(String)
        if !ENV['AWS_REGION'].nil? && ENV['AWS_REGION'] != value
          fail "if using AWS_REGION environment variable it must match the specified region value for #{name}"
        end
      end
    end
  end
end
