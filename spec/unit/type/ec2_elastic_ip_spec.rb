require 'spec_helper'

type_class = Puppet::Type.type(:ec2_elastic_ip)

describe type_class do

  let :params do
    [
      :name,
    ]
  end

  let :properties do
    [
      :ensure,
      :instance,
      :region,
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

  it 'should require a valid ip address for the name' do
    expect {
      type_class.new({ name: 'invalid' })
    }.to raise_error(Puppet::Error, /The name of an Elastic IP address must be a valid IP/)
  end

  it 'should require a region to be specified' do
    expect {
      type_class.new({ name: '10.0.0.1', region: '' })
    }.to raise_error(Puppet::Error, /You must provide a region for Elastic IPs/)
  end

  it 'should require an instance to be specified' do
    expect {
      type_class.new({ name: '10.0.0.1', region: 'us-east-1', instance: '' })
    }.to raise_error(Puppet::Error, /You must provide an instance for the Elastic IP association/)
  end

  it 'should not work with :present' do
    expect {
      type_class.new({ name: '10.0.0.1', :ensure => :present })
    }.to raise_error(Puppet::Error, /Invalid value :present. Valid values are attached, detached./)
  end

  it 'should not work with :absent' do
    expect {
      type_class.new({ name: '10.0.0.1', :ensure => :absent })
    }.to raise_error(Puppet::Error, /Invalid value :absent. Valid values are attached, detached./)
  end

  it 'should support :attached as a value to :ensure' do
    type_class.new(:name => '10.0.0.1', :ensure => :attached)
  end

  it 'should support :detached as a value to :ensure' do
    type_class.new(:name => '10.0.0.1', :ensure => :detached)
  end

  context 'with valid properties' do
    it 'should create a valid elastic ip ' do
      type_class.new({ name: '10.0.0.1', region: 'us-east-1', instance: 'web-1' })
    end
  end

end
