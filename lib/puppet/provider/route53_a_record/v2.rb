require_relative '../route53_record'

Puppet::Type.type(:route53_a_record).provide(:v2, :parent => Puppet::Provider::Route53Record) do
  confine feature: :aws

  mk_resource_methods

  def self.record_type
    'A'
  end

  def flush
    update unless @property_hash[:ensure] == :absent
  end
end
