require 'spec_helper'

type_class = Puppet::Type.type(:ec2_vpc)

describe type_class do

  let :params do
    [
      :name,
    ]
  end

  let :properties do
    [
      :ensure,
      :cidr_block,
      :dhcp_options,
      :region,
      :enable_dns_support,
      :enable_dns_hostnames,
      :instance_tenancy,
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

  it 'should default instance tenancy to default' do
    srv = type_class.new(:name => 'sample')
    expect(srv[:instance_tenancy]).to eq(:default)
  end

  it 'should be able to set instance tenancy to dedicated' do
    srv = type_class.new(:name => 'sample', :instance_tenancy => 'dedicated')
    expect(srv[:instance_tenancy]).to eq(:dedicated)
  end

  it 'should not be able to set instance tenancy to arbitrary values' do
    expect {
      type_class.new(:name => 'sample', :instance_tenancy => 'invalid')
    }.to raise_error(Puppet::ResourceError, /Invalid value "invalid"/)
  end

  it 'region should not contain spaces' do
    expect {
      type_class.new(:name => 'sample', :region => 'sa east 1')
    }.to raise_error(Puppet::ResourceError, /region should be a valid AWS region/)
  end

  it 'should order tags on output' do
    expect(type_class).to order_tags_on_output
  end

  [
    'name',
    'region',
    'dhcp_options',
  ].each do |property|
    it "should require #{property} to be a string" do
      expect(type_class).to require_string_for(property)
    end
  end

  it 'should default to dns support enabled' do
    vpc = type_class.new({:name => 'sample'})
    expect(vpc[:enable_dns_support]).to eq(:true)
  end

  it 'should default to dns hostnames enabled' do
    vpc = type_class.new({:name => 'sample'})
    expect(vpc[:enable_dns_hostnames]).to eq(:true)
  end

  it 'should not allow invalid values for dns support' do
    expect {
      type_class.new({:name => 'sample', :enable_dns_support => 'invalid'})
    }.to raise_error(Puppet::Error)
  end

  it 'should not allow invalid values for dns hostnames' do
    expect {
      type_class.new({:name => 'sample', :enable_dns_hostnames => 'invalid'})
    }.to raise_error(Puppet::Error)
  end

  it 'should allow valid values for dns support' do
    vpc = type_class.new({:name => 'sample', :enable_dns_support => false})
    expect(vpc[:enable_dns_support]).to eq(:false)
  end

  it 'should allow valid values for dns hostnames' do
    vpc = type_class.new({:name => 'sample', :enable_dns_hostnames => false})
    expect(vpc[:enable_dns_hostnames]).to eq(:false)
  end

  it "should require tags to be a hash" do
    expect(type_class).to require_hash_for('tags')
  end

end
