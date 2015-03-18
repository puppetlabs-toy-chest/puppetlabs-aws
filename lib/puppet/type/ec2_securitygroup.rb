require_relative '../../puppet_x/puppetlabs/property/tag.rb'

Puppet::Type.newtype(:ec2_securitygroup) do
  @doc = 'type representing an EC2 security group'

  ensurable

  newparam(:name, namevar: true) do
    desc 'the Name tag of the security group'
  end

  newparam(:group_name) do
    desc 'the name of the security group in AWS'
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
      order_ingress(stringify_values(should)) == order_ingress(stringify_values(is))
    end

    def order_ingress(rules)
      cidrs, groups = rules.partition { |rule| rule['cidr'] }
      groups.sort_by! do |g|
        %w{security_group protocol port}.map{|k| g[k] || ' '}.flatten.join '!'
      end
      cidrs.sort_by! do |g|
        %w{cidr protocol port}.map{|k| g[k] || ' '}.flatten.join '!'
      end

      groups + cidrs
    end

    def stringify_values(rules)
      rules.map {|rule| rule.inject({}) { |h,kv| h.merge!(Hash[*kv]) } }
    end
  end

  newproperty(:tags, :parent => PuppetX::Property::AwsTag) do
    desc 'the tags for the security group'
  end

  newproperty(:description) do
    desc 'a short description of the group'
    validate do |value|
      fail Puppet::Error, 'description cannot be blank' if value == ''
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
