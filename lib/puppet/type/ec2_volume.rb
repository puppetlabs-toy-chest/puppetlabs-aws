require_relative '../../puppet_x/puppetlabs/property/tag.rb'
require 'puppet/property/boolean'

Puppet::Type.newtype(:ec2_volume) do
  @doc = 'type representing an EC2 Block Device'

  ensurable

  newparam(:name, namevar: true) do
    desc 'the name of the security group'
    validate do |value|
      fail 'Volume must have a name' if value == ''
      fail 'name should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:region) do
    desc 'the region in which to launch the volume'
    validate do |value|
      fail 'region should not contain spaces' if value =~ /\s/
      fail 'region should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:tags, :parent => PuppetX::Property::AwsTag) do
    desc 'the tags for the volume'
  end

  newproperty(:description) do
    desc 'a short description of the volume'
    validate do |value|
      fail 'description cannot be blank' if value == ''
      fail 'description should be a String' unless value.is_a?(String)
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

  newproperty(:size) do
    desc 'The size in GB of the volume.'
    validate do |value|
      fail 'Size should be a integer' unless value =~ /^\d+$/
    end
  end

  newproperty(:volume_id) do
    desc 'aws id of volume'
    validate do |value|
      fail "Volume Type should be a String: #{value}" unless value.is_a?(String)
    end
  end

  newproperty(:volume_type) do
    desc 'standard, io1, gp2'
    validate do |value|
      fail "Volume Type should be a String: #{value}" unless value.is_a?(String)
    end
  end

  newproperty(:snapshot_id) do
    desc 'The snapshot that this volume should be created from'
    validate do |value|
      fail 'snapshot_id should be an string' unless value.is_a?(String)
    end
  end

  newproperty(:attach) do
    desc 'The ec2 instance that this volume should attach to'
    validate do |value|
      attachments = value.is_a?(Array) ? value : [value]
      attachments.each do |params|
        fail "must supply instance id" unless value.keys.include?('instance_id')
        fail "must supply device name" unless value.keys.include?('device')
      end
    end
  end

  newproperty(:iops) do
    desc 'Provisioned iops for volume'
    validate do |value|
      fail 'iops should be an integer' unless value =~ /^\d+$/
    end
  end

  newproperty(:kms_key_id) do
    desc 'The full ARN of the AWS Key Management Service (AWS KMS) customer master key (CMK) to use when creating the encrypted volume.'
    validate do |value|
      fail 'kms_key_id should be an string' unless value.is_a?(String)
    end
  end

  newproperty(:encrypted, parent: Puppet::Property::Boolean) do
    desc 'Indicates whether newly created volume should be encrypted.'
  end
end
