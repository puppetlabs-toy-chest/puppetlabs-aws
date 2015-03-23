require 'spec_helper'

type_class = Puppet::Type.type(:ec2_vpc_vpn_gateway)

describe type_class do

  let :params do
    [
      :name,
      :availability_zone,
    ]
  end

  let :properties do
    [
      :ensure,
      :tags,
      :vpc,
      :type,
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

  it 'region should not contain spaces' do
    expect {
      type_class.new(:name => 'sample', :region => 'sa east 1')
    }.to raise_error(Puppet::ResourceError, /region should not contain spaces/)
  end

  it 'should default type to ipsec.1' do
    srv = type_class.new(:name => 'sample')
    expect(srv[:type]).to eq('ipsec.1')
  end

  [
    'name',
    'region',
    'vpc',
    'availability_zone',
  ].each do |property|
    it "should require #{property} to be a string" do
      expect(type_class).to require_string_for(property)
    end
  end

  it "should require tags to be a hash" do
    expect(type_class).to require_hash_for('tags')
  end

end
