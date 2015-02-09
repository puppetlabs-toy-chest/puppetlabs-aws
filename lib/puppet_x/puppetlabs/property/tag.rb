module PuppetX
  module Property
    class AwsTag < Puppet::Property

      def format_tags(value)
        Hash[value.sort]
      end

      [:should_to_s, :is_to_s].each { |method|
        alias_method method, :format_tags
      }
    end
  end
end
