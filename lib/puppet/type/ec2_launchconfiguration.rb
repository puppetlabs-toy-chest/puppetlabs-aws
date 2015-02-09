Puppet::Type.newtype(:ec2_launchconfiguration) do
  @doc = 'Type representing an EC2 launch configuration.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the launch configuration.'
    validate do |value|
      fail 'launch configurations must have a name' if value == ''
    end
  end

  newproperty(:security_groups, :array_matching => :all) do
    desc 'The security groups to associate with the instances.'
    validate do |value|
      fail 'you must specifiy security groups for the launch configuration' if value.empty?
    end
    def insync?(is)
      is.to_set == should.to_set
    end
  end

  newparam(:user_data) do
    desc 'User data script to execute on new instances.'
  end

  newproperty(:key_name) do
    desc 'The name of the key pair associated with this instance.'
  end

  newproperty(:region) do
    desc 'The region in which to launch the instances.'
    validate do |value|
      fail 'region should not contain spaces' if value =~ /\s/
      fail 'region should not be blank' if value == ''
    end
  end

  newproperty(:instance_type) do
    desc 'The type to use for the instances.'
    validate do |value|
      fail 'instance_type should not contains spaces' if value =~ /\s/
      fail 'instance_type should not be blank' if value == ''
    end
  end

  newproperty(:image_id) do
    desc 'The image id to use for the instances.'
    validate do |value|
      fail 'image_id should not contain spaces' if value =~ /\s/
      fail 'image_id should not be blank' if value == ''
    end
  end

  autorequire(:ec2_securitygroup) do
    groups = self[:security_groups]
    groups.is_a?(Array) ? groups : [groups]
  end

end
