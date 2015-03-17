require_relative '../../puppet_x/puppetlabs/route53_record'

Puppet::Type.newtype(:route53_srv_record) do
  extend PuppetX::Puppetlabs::Route53Record
  @doc = 'Type representing a Route53 SRV record.'
  create_properties_and_params()
end

