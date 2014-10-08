Puppet::Type.newtype(:route53_zone) do
  @doc = 'type representing an Route53 DNS zone'

  ensurable

  newparam(:name, namevar: true) do
    desc 'the name of DNS zone group'
    validate do |value|
      fail Puppet::Error, 'Zone names must be all lowercase' unless value.downcase == value
      fail Puppet::Error, 'Zone names must end with a period' unless value.end_with?('.')
      fail Puppet::Error, 'Empty values are not allowed' if value == ''
    end
  end

end
