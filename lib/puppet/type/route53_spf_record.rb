require_relative '../../puppet_x/puppetlabs/route53_record'

Puppet::Type.newtype(:route53_spf_record) do
  extend PuppetX::Puppetlabs::Route53Record
  @doc = 'Type representing a Route53 SPF record.'
  create_properties_and_params()

  # SPF records should always be wrapped in double quotes
  # this munge avoids the need to pass in a '"value"' to Puppet
  values_property = self.properties.find { |item| item == Puppet::Type::Route53_spf_record::Values }
  values_property.munge do |value|
    value =~ /^".+"$/ ? value : "\"#{value}\""
  end
end

