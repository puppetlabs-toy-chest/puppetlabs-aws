require_relative '../../puppet_x/puppetlabs/route53_record'

Puppet::Type.newtype(:route53_ns_record) do
  extend PuppetX::Puppetlabs::Route53Record
  @doc = 'Type representing a Route53 DNS record.'
  create_properties_and_params()
end

