Puppet::Type.newtype(:ec2_securitygroup) do
  @doc = 'type representing an EC2 security group'

  ensurable

  newparam(:name, namevar: true) do
    desc 'the name of the security group'
    validate do |value|
      fail Puppet::Error, 'Security groups must have a name' if value == ''
    end
  end

  newproperty(:region) do
    desc 'the region in which to launch the security group'
    validate do |value|
      fail Puppet::Error, 'region should not contains spaces' if value =~ /\s/
    end
  end

  newproperty(:ingress, :array_matching => :all) do
    desc 'rules for ingress traffic'
    def insync?(is)
      order_ingress(should) == order_ingress(stringify_values(is))
    end

    def order_ingress(rules)
      groups, ports = rules.partition { |rule| rule['security_group'] }
      groups.sort_by! { |group| group['security_group'] }
      ports.sort! { |a, b| [a['protocol'], a['port']] <=> [b['protocol'], b['port']] }

      groups + ports
    end

    def stringify_values(rules)
      rules.collect do |obj|
        obj.each { |k,v| obj[k] = v.to_s }
      end
    end
  end

  newparam(:tags, :array_matching => :all) do
    desc 'the tags for the security group'
  end

  newproperty(:description) do
    desc 'a short description of the group'
    validate do |value|
      fail Puppet::Error, 'description cannot be blank' if value == ''
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
end
