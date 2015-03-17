require_relative '../../puppet_x/puppetlabs/route53_record'

Puppet::Type.newtype(:route53_mx_record) do
  extend PuppetX::Puppetlabs::Route53Record
  @doc = 'Type representing a Route53 MX record.'
  create_properties_and_params()
end

