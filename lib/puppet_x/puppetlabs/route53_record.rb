module PuppetX
  module Puppetlabs
    module Route53Record
      def create_properties_and_params
        ensurable
        newproperty(:zone) do
          desc 'the zone associated with this record'
          validate do |value|
            fail 'The name of the zone must not be blank' if value.empty?
            fail 'Zone names must end with a .' if value[-1] != '.'
          end
        end

        newparam(:name) do
          desc 'the name of DNS record'
          isnamevar
          validate do |value|
            fail 'The name of the record must not be blank' if value.empty?
            fail 'Record names must end with a .' if value[-1] != '.'
          end
        end

        newproperty(:ttl) do
          desc 'the time to live for the record'
          def insync?(is)
            is.to_i == should.to_i
          end
        end

        newproperty(:values, :array_matching => :all) do
          desc 'the values of the record'
          validate do |value|
            fail 'The value of the record must not be blank' if value.empty?
          end
        end

        autorequire(:route53_zone) do
          self[:zone]
        end
      end
    end
  end
end
