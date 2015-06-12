require_relative '../../puppet_x/puppetlabs/property/tag.rb'

Puppet::Type.newtype(:ec2_instance) do
  @doc = 'Type representing an EC2 instance.'

  newproperty(:ensure) do
    newvalue(:present) do
      provider.create unless provider.running?
    end
    newvalue(:absent) do
      provider.destroy if provider.exists?
    end
    newvalue(:running) do
      provider.create unless provider.running?
    end
    newvalue(:stopped) do
      provider.stop unless provider.stopped?
    end
    def change_to_s(current, desired)
      current = :running if current == :present
      desired = :running if desired == :present
      current == desired ? current : "changed #{current} to #{desired}"
    end
    def insync?(is)
      is = :present if is == :running
      is = :stopped if is == :stopping
      is.to_s == should.to_s
    end
  end

  newparam(:name, namevar: true) do
    desc 'The name of the instance.'
    validate do |value|
      fail 'Instances must have a name' if value == ''
      fail 'name should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:security_groups, :array_matching => :all) do
    desc 'The security groups to associate the instance.'
    def insync?(is)
      is.to_set == should.to_set
    end
    validate do |value|
      fail 'security_groups should be a String' unless value.is_a?(String)
    end
  end

  newparam(:iam_instance_profile_name) do
    desc 'The name of the amazon IAM role you want the ec2 instance to operate under'
  end

  newproperty(:iam_instance_profile_arn) do
    desc 'The arn of the amazon IAM role you want the ec2 instance to operate under'
  end

  validate do
    fail "You can specify either an IAM name or an IAM arn but not both for the ec2 instance [#{self[:name]}]" if self[:iam_instance_profile_name] && self[:iam_instance_profile_arn]
  end

  newproperty(:tags, :parent => PuppetX::Property::AwsTag) do
    desc 'The tags for the instance.'
  end

  newparam(:user_data) do
    desc 'User data script to execute on new instance.'
  end

  newparam(:associate_public_ip_address) do
    desc 'Whether to assign a public interface in a VPC.'
    defaultto :false
    newvalues(:true, :'false')
    def insync?(is)
      is.to_s == should.to_s
    end
  end

  newproperty(:key_name) do
    desc 'The name of the key pair associated with this instance.'
    validate do |value|
      fail 'key_name should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:monitoring) do
    desc 'Whether or not monitoring is enabled for this instance.'
    defaultto :false
    newvalues(:true, :'false')
    def insync?(is)
      is.to_s == should.to_s
    end
  end

  newproperty(:region) do
    desc 'The region in which to launch the instance.'
    validate do |value|
      fail 'region should not contain spaces' if value =~ /\s/
      fail 'region should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:image_id) do
    desc 'The image id to use for the instance.'
    validate do |value|
      fail 'image_id should not contain spaces' if value =~ /\s/
      fail 'image_id should not be blank' if value == ''
      fail 'image_id should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:availability_zone) do
    desc 'The availability zone in which to place the instance.'
    validate do |value|
      fail 'availability_zone should not contain spaces' if value =~ /\s/
      fail 'availability_zone should not be blank' if value == ''
      fail 'availability_zone should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:instance_type) do
    desc 'The type to use for the instance.'
    validate do |value|
      fail 'instance type should not contains spaces' if value =~ /\s/
      fail 'instance_type should not be blank' if value == ''
      fail 'instance_type should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:instance_id) do
    desc 'The AWS generated id for the instance.'
    validate do |value|
      fail 'instance_id is read-only'
    end
  end

  newproperty(:hypervisor) do
    desc 'The type of hypervisor running the instance.'
    validate do |value|
      fail 'hypervisor is read-only'
    end
  end

  newproperty(:virtualization_type) do
    desc 'The underlying virtualization of the instance.'
    validate do |value|
      fail 'virtualization_type is read-only'
    end
  end

  newproperty(:private_ip_address) do
    desc 'The private IP address for the instance.'
    validate do |value|
      fail 'private ip address must be a valid ipv4 address' unless value =~ Resolv::IPv4::Regex
    end
  end

  newproperty(:public_ip_address) do
    desc 'The public IP address for the instance.'
    validate do |value|
      fail 'public_ip_address is read-only'
    end
  end

  newproperty(:private_dns_name) do
    desc 'The internal DNS name for the instance.'
    validate do |value|
      fail 'private_dns_name is read-only'
    end
  end

  newproperty(:public_dns_name) do
    desc 'The publicly available DNS name for the instance.'
    validate do |value|
      fail 'public_dns_name is read-only'
    end
  end

  newproperty(:subnet) do
    desc 'The VPC subnet to attach the instance to.'
    validate do |value|
      fail 'subnet should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:ebs_optimized) do
    desc 'Whether or not to use obtimized storage for the instance.'
    defaultto :false
    newvalues(:true, :'false')
    def insync?(is)
      is.to_s == should.to_s
    end
  end

  newparam(:instance_initiated_shutdown_behavior) do
    desc 'Whether the instance stops or terminates when you initiate shutdown from the instance.'
    defaultto :stop
    newvalues(:stop, :terminate)
    def insync?(is)
      is.to_s == should.to_s
    end
  end

  newproperty(:kernel_id) do
    desc 'The ID of the kernel in use by the instance.'
    validate do |value|
      fail 'kernel_id is read-only'
    end
  end

  newproperty(:block_devices, :array_matching => :all) do
    desc 'A list of block devices to associate with the instance'
    validate do |value|
      devices = value.is_a?(Array) ? value : [value]
      devices.each do |device|
        fail "block device must include 'device_name'" unless value.keys.include?('device_name')
        if value['virtual_name'] !~ /ephemeral\d+/
          fail "block device must include 'volume_size' for ebs volumes" unless value.keys.include?('volume_size')
          if value['volume_type'] == 'io1'
            fail 'must specify iops if using provisioned iops volumes' unless value.keys.include?('iops')
          end
        end
      end
    end
    def insync?(is)
      existing_devices = is.collect { |device| device[:device_name] }
      specified_devices = should.collect { |device| device['device_name'] }
      existing_devices.to_set == specified_devices.to_set
    end
  end

  autorequire(:ec2_securitygroup) do
    groups = self[:security_groups]
    groups.is_a?(Array) ? groups : [groups]
  end

  autorequire(:ec2_vpc_subnet) do
    self[:subnet]
  end

end
