require_relative '../../puppet_x/puppetlabs/property/tag.rb'
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

  newproperty(:region) do
    desc 'the region in which to launch the security group'
    validate do |value|
      fail 'region should not contains spaces' if value =~ /\s/
    end
  end

  newproperty(:ingress, :array_matching => :all) do
    desc 'rules for ingress traffic'

    def insync?(is)
      s = should.map{|rule| normalize_ports(rule)}
      i = is.map{|rule| normalize_ports(rule)}

      (s - i).empty? && (i - s).empty?
    end

    def normalize_ports(rule)
      copy = Marshal.load(Marshal.dump(rule))

      port = copy['port']
      port = if port.is_a? String
        port.to_i
      elsif port.is_a? Array
        port.map {|p| p.is_a?(String) ? p.to_i : p}
      else
        port
      end

      copy['port'] = port if port
      copy
    end
  end

  newproperty(:tags, :parent => PuppetX::Property::AwsTag) do
    desc 'the tags for the security group'
  end

  newproperty(:description) do
    desc 'a short description of the group'
    validate do |value|
      fail 'description cannot be blank' if value == ''
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
