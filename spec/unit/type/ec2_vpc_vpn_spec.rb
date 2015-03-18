require 'spec_helper'

type_class = Puppet::Type.type(:ec2_vpc_vpn)

describe type_class do

  let :params do
    [
      :name,
    ]
  end

  let :properties do
    [
      :ensure,
      :region,
      :vpn_gateway,
      :customer_gateway,
      :type,
      :routes,
      :static_routes,
      :tags,
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

  it 'should default type to ipsec.1' do
    srv = type_class.new(:name => 'sample')
    expect(srv[:type]).to eq('ipsec.1')
  end

  it 'should default static routes to true' do
    srv = type_class.new(:name => 'sample')
    expect(srv[:static_routes]).to eq(:true)
  end

  it 'should be able to set static routes to false' do
    srv = type_class.new(:name => 'sample', :static_routes => false)
    expect(srv[:static_routes]).to eq(:false)
  end

  it 'should not be able to set static routes to arbitrary values' do
    expect {
      type_class.new(:name => 'sample', :static_routes => 'invalid')
    }.to raise_error(Puppet::ResourceError, /Invalid value "invalid"/)
  end

  it 'region should not contain spaces' do
    expect {
      type_class.new(:name => 'sample', :region => 'sa east 1')
    }.to raise_error(Puppet::ResourceError, /region should not contain spaces/)
  end

  [
    'name',
    'vpn_gateway',
    'customer_gateway',
    'routes',
    'region',
  ].each do |property|
    it "should require #{property} to be a string" do
      expect(type_class).to require_string_for(property)
    end
  end

  it "should require tags to be a hash" do
    expect(type_class).to require_hash_for('tags')
  end

end
