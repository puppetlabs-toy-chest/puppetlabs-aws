require_relative '../../puppet_x/puppetlabs/property/tag.rb'
require_relative '../../puppet_x/puppetlabs/aws_ingress_rules_parser'

Puppet::Type.newtype(:ec2_securitygroup) do
  @doc = 'type representing an EC2 security group'

  ensurable

  newparam(:name) do
    desc 'the name of the security group resource'
    isnamevar
    validate do |value|
      fail 'security groups must have a name' if value == ''
      fail 'name should be a String' unless value.is_a?(String)
    end
  end

  newparam(:group_name) do
    desc 'the name of the security group'
    isnamevar
  end

  newproperty(:region) do
    desc 'the region in which to launch the security group'
    validate do |value|
      fail 'region should not contain spaces' if value =~ /\s/
      fail 'region should be a String' unless value.is_a?(String)
    end
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

    validate do |value|
      fail 'ingress should be a Hash' unless value.is_a?(Hash)
    end
  end

  newproperty(:tags, :parent => PuppetX::Property::AwsTag) do
    desc 'the tags for the security group'
  end

  newproperty(:description) do
    desc 'a short description of the group'
    validate do |value|
      fail 'description cannot be blank' if value == ''
      fail 'description should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:vpc) do
    desc 'A VPC to which the group should be associated'
    isnamevar
    validate do |value|
      fail 'vpc should be a String' unless value.is_a?(String)
    end
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

  # When you create a VPC you automatically get a security group called default. You can't change the name.
  # This lack of uniqueness makes managing these default security groups difficult. Enter a composite namevar.
  # We support two name formats:
  #
  #   1. {some-security-group}
  #   2. {some-vpc-name}::default
  #
  # Note that we only support prefixing a security group name with the vpc name for the default security group
  # at this point. This avoids the issue of otherwise needing to store the resources in two places for non-default
  # VPC security groups.
  #
  # In the case of a a default security group, we maintain the full name (including the VPC name) in the name property
  # as otherwise it won't be unique and uniqueness and composite namevars are fun.
  def self.title_patterns
    [
      [ /^(([\w\-]+)::(default))$/, [ [ :name, lambda {|x| x} ], [ :vpc, lambda {|x| x} ], [ :group_name, lambda {|x| x} ] ] ],
      [ /^((.*))$/, [ [ :name, lambda {|x| x} ], [ :group_name, lambda {|x| x} ] ] ]
    ]
  end

end
