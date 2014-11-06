Puppet::Type.newtype(:ec2_instance) do
  @doc = 'type representing an EC2 instance'

  ensurable do
    defaultvalues
    aliasvalue(:running, :present)
    newvalue(:stopped) do
      provider.stop
    end
  end

  newparam(:name, namevar: true) do
    desc 'the name of the instance'
    validate do |value|
      fail Puppet::Error, 'Empty values are not allowed' if value == ''
    end
  end

  newparam(:security_groups, :array_matching => :all) do
    desc 'the security groups to associate the instance'
  end

  newproperty(:tags) do
    desc 'the tags for the instance'
  end

  newparam(:user_data) do
    desc 'user data script to execute on new instance'
  end

  newproperty(:instance_id) do
    desc 'the AWS generated id for the instance'
  end

  newproperty(:key_name) do
    desc 'the name of the key pair associated with this instance'
  end

  newproperty(:monitoring) do
    desc 'whether or not monitoring is enabled for this instance'
    defaultto :false
    newvalues(:true, :'false')
    def insync?(is)
      is.to_s == should.to_s
    end
  end

  newproperty(:region) do
    desc 'the region in which to launch the instance'
    validate do |value|
      fail Puppet::Error, 'Should not contains spaces' if value =~ /\s/
    end
  end

  newproperty(:image_id) do
    desc 'the image id to use for the instance'
    validate do |value|
      fail Puppet::Error, 'Should not contains spaces' if value =~ /\s/
      fail Puppet::Error, 'Empty values are not allowed' if value == ''
    end
  end

  newproperty(:availability_zone) do
    desc 'the availability zone in which to place the instance'
    validate do |value|
      fail Puppet::Error, 'Should not contains spaces' if value =~ /\s/
      fail Puppet::Error, 'Empty values are not allowed' if value == ''
    end
  end

  newproperty(:instance_type) do
    desc 'the type to use for the instance'
    validate do |value|
      fail Puppet::Error, 'Should not contains spaces' if value =~ /\s/
      fail Puppet::Error, 'Empty values are not allowed' if value == ''
    end
  end

  newproperty(:subnet) do
    desc 'the VPC subnet to attach the instance to'
  end

  autorequire(:ec2_securitygroup) do
    groups = self[:security_groups]
    groups.is_a?(Array) ? groups : [groups]
  end

end
