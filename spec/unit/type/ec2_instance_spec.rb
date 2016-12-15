require 'spec_helper'

type_class = Puppet::Type.type(:ec2_instance)

describe type_class do

  let :params do
    [
      :name,
      :instance_initiated_shutdown_behavior,
      :associate_public_ip_address,
      :iam_instance_profile_name,
    ]
  end

  let :properties do
    [
      :ensure,
      :security_groups,
      :image_id,
      :instance_type,
      :region,
      :availability_zone,
      :monitoring,
      :tenancy,
      :key_name,
      :subnet,
      :ebs_optimized,
      :iam_instance_profile_arn,
      :interfaces,
    ]
  end

  it 'should have expected properties' do
    properties.each do |property|
      expect(type_class.properties.map(&:name)).to be_include(property)
    end
  end

  it 'should have expected parameters' do
    params.each do |param|
      expect(type_class.parameters).to be_include(param)
    end
  end

  it 'should require a name' do
    expect {
      type_class.new({})
    }.to raise_error(Puppet::Error, 'Title or name must be provided')
  end

  it 'should support :stopped as a value to :ensure' do
    type_class.new(:name => 'sample', :ensure => :stopped)
  end

  it 'should support :running as a value to :ensure' do
    type_class.new(:name => 'sample', :ensure => :running)
  end

  it 'should acknowledge stopped instance to be present' do
    machine = type_class.new(:name => 'sample', :ensure => :present)
    expect(machine.property(:ensure).insync?(:stopped)).to be true
  end

  it 'should acknowledge stopping instance to be present' do
    machine = type_class.new(:name => 'sample', :ensure => :present)
    expect(machine.property(:ensure).insync?(:stopping)).to be true
  end

  it 'should acknowledge running instance to be present' do
    machine = type_class.new(:name => 'sample', :ensure => :present)
    expect(machine.property(:ensure).insync?(:running)).to be true
  end

  it 'should acknowledge stopping instance to be stopped' do
    machine = type_class.new(:name => 'sample', :ensure => :stopped)
    expect(machine.property(:ensure).insync?(:stopping)).to be true
  end

  it 'should acknowledge running instance to be running' do
    machine = type_class.new(:name => 'sample', :ensure => :running)
    expect(machine.property(:ensure).insync?(:running)).to be true
  end

  it 'should default monitoring to false' do
    srv = type_class.new(:name => 'sample')
    expect(srv[:monitoring]).to eq(:false)
  end

  it 'should default allocating a public ip to false' do
    srv = type_class.new(:name => 'sample')
    expect(srv[:associate_public_ip_address]).to eq(:false)
  end

  it 'should default ebs obtimized to false' do
    srv = type_class.new(:name => 'sample')
    expect(srv[:monitoring]).to eq(:false)
  end

  it 'should default instance_initiated_shutdown_behavior to stop' do
    srv = type_class.new(:name => 'sample')
    expect(srv[:instance_initiated_shutdown_behavior]).to eq(:stop)
  end

  it 'if block device included must include a device name' do
    expect {
      type_class.new({:name => 'sample', :block_devices => [
        {'volume_size' => 8}
      ]})
    }.to raise_error(Puppet::Error, /block device must be named/)
  end

  it 'if block device included must include a volume size or snapshot' do
    expect {
      type_class.new({:name => 'sample', :block_devices => [
        {'device_name' => '/dev/sda1'}
      ]})
    }.to raise_error(Puppet::Error, /block device must include at least one of: volume_size snapshot_id/)
  end

  it 'if private IP included must be a valid IP' do
    expect {
      type_class.new({:name => 'sample', :private_ip_address => 'invalid'})
    }.to raise_error(Puppet::Error, /private ip address must be a valid ipv4 address/)
  end

  it 'if a provisioned iops block device included must include iops' do
    expect {
      type_class.new({:name => 'sample', :block_devices => [{
        'device_name' => '/dev/sda1',
        'volume_size' => 8,
        'volume_type' => 'io1',
      }]})
    }.to raise_error(Puppet::Error, /must specify iops if using provisioned iops/)
  end

  it 'should order tags on output' do
    expect(type_class).to order_tags_on_output
  end

  [
    'name',
    'region',
    'security_groups',
    'key_name',
    'region',
    'image_id',
    'availability_zone',
    'instance_type',
    'subnet',
  ].each do |property|
    it "should require #{property} to be a string" do
      expect(type_class).to require_string_for(property)
    end
  end

  it 'should disallow passing both an IAM role name and an IAM role ARN' do
    expect {
      type_class.new({:name => 'sample', :iam_instance_profile_arn => '1234::ARN', :iam_instance_profile_name => 'foobar'})
    }.to raise_error(Puppet::Error)
  end
end
