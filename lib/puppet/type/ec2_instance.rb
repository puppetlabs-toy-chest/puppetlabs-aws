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
      fail 'Instances must have a name' if value == ''
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
      fail 'region should not contain spaces' if value =~ /\s/
    end
  end

  newproperty(:image_id) do
    desc 'the image id to use for the instance'
    validate do |value|
      fail 'image_id should not contain spaces' if value =~ /\s/
      fail 'image_id should not be blank' if value == ''
    end
  end

  newproperty(:availability_zone) do
    desc 'the availability zone in which to place the instance'
    validate do |value|
      fail 'availability_zone should not contain spaces' if value =~ /\s/
      fail 'availability_zone should not be blank' if value == ''
    end
  end

  newproperty(:instance_type) do
    desc 'the type to use for the instance'
    validate do |value|
      fail 'instance type should not contains spaces' if value =~ /\s/
      fail 'instance_type should not be blank' if value == ''
    end
  end

  newproperty(:instance_id) do
    desc 'the AWS generated id for the instance'
    validate do |value|
      fail "instance_id is read-only"
    end
  end

  newproperty(:hypervisor) do
    desc 'the type of hypervisor running the instance'
    validate do |value|
      fail "hypervisor is read-only"
    end
  end

  newproperty(:virtualization_type) do
    desc 'the underlying virtualization of the instance'
    validate do |value|
      fail "virtualization_type is read-only"
    end
  end

  newproperty(:private_ip_address) do
    desc 'the private IP address for the instance'
    validate do |value|
      fail "instance_id is read-only"
    end
  end

  newproperty(:public_ip_address) do
    desc 'the public IP address for the instance'
    validate do |value|
      fail "public_ip_address is read-only"
    end
  end

  newproperty(:private_dns_name) do
    desc 'the internal DNS name for the instance'
    validate do |value|
      fail "private_dns_name is read-only"
    end
  end

  newproperty(:public_dns_name) do
    desc 'the publicly available DNS name for the instance'
    validate do |value|
      fail "public_dns_name is read-only"
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
