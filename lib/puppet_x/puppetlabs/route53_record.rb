module PuppetX
  module Puppetlabs
    module Route53Record
      def create_properties_and_params
        ensurable
        newproperty(:zone) do
          desc 'The zone associated with this record.'
          validate do |value|
            fail 'The name of the zone must not be blank' if value.empty?
            fail 'Zone names must end with a .' if value[-1] != '.'
          end
        end

        newparam(:name) do
          desc 'The name of DNS record.'
          isnamevar
          validate do |value|
            fail 'The name of the record must not be blank' if value.empty?
            fail 'Record names must end with a .' if value[-1] != '.'
          end
        end

        newproperty(:ttl) do
          desc 'The time to live for the record.'
          munge do |value|
            value.to_i
          end
          validate do |value|
            fail 'TTL values must be integers' unless value.to_i.to_s == value.to_s
          end
        end

        newproperty(:values, :array_matching => :all) do
          desc 'The values of the record.'
          validate do |value|
            fail 'The value of the record must not be blank' if value.empty?
          end
          def insync?(is)
            is.to_set == should.to_set
          end
        end

        autorequire(:route53_zone) do
          self[:zone]
        end
      end
    end
  end
end
