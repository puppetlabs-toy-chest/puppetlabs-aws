require_relative '../../puppet_x/puppetlabs/property/tag.rb'
require_relative '../../puppet_x/puppetlabs/property/region'
require_relative '../../puppet_x/puppetlabs/aws_ingress_rules_parser'

Puppet::Type.newtype(:ec2_securitygroup) do
  @doc = 'type representing an EC2 security group'

  ensurable

  newparam(:name, namevar: true) do
    desc 'the name of the security group'
    validate do |value|
      fail 'Security groups must have a name' if value == ''
    end
  end

  newproperty(:region, :parent => PuppetX::Property::AwsRegion) do
    desc 'the region in which to launch the security group'
  end

  newproperty(:ingress, :array_matching => :all) do
    desc 'rules for ingress traffic'
    def insync?(is)
      for_comparison = Marshal.load(Marshal.dump(should))
      parser = PuppetX::Puppetlabs::AwsIngressRulesParser.new(for_comparison)
      to_create = parser.rules_to_create(is)
      to_delete = parser.rules_to_delete(is)
      to_create.empty? && to_delete.empty?
    end
  end

  newproperty(:tags, :parent => PuppetX::Property::AwsTag) do
    desc 'the tags for the security group'
  end

  newproperty(:description) do
    desc 'a short description of the group'
    validate do |value|
      fail  'description cannot be blank' if value == ''
    end
  end

  newproperty(:vpc) do
    desc 'A VPC to which the group should be associated'
  end

  def should_autorequire?(rule)
    !rule.nil? and rule.key? 'security_group' and rule['security_group'] != name
  end

  autorequire(:ec2_securitygroup) do
    rules = self[:ingress]
    rules = [rules] unless rules.is_a?(Array)
    rules.collect do |rule|
      rule['security_group'] if should_autorequire?(rule)
    end
  end

  autorequire(:ec2_vpc) do
    self[:vpc]
  end
end
