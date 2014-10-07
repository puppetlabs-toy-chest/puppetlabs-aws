Puppet::Type.newtype(:route53_zone) do
  @doc = 'type representing an Route53 DNS zone'

  ensurable

  newparam(:name, namevar: true) do
    desc 'the name of DNS zone group'
    validate do |value|
      fail Puppet::Error, 'Empty values are not allowed' if value == ''
    end
  end

end
