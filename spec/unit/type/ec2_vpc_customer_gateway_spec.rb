require 'spec_helper'

type_class = Puppet::Type.type(:ec2_vpc_customer_gateway)

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
      :ip_address,
      :bgp_asn,
      :tags,
      :type,
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
    }.to raise_error(Puppet::ResourceError, /region should be a valid AWS region/)
  end

  it 'the ASN should be a number' do
    expect {
      type_class.new({:name => 'sample', :bgp_asn => 'invalid'})
    }.to raise_error(Puppet::ResourceError, /'invalid' is not a valid BGP ASN/)

    expect {
      type_class.new({:name => 'sample', :bgp_asn => '1001'})
    }.not_to raise_error
  end

  it 'the ip_address should be an ip_address' do
    expect {
      type_class.new({:name => 'sample', :ip_address => 'invalid'})
    }.to raise_error(Puppet::ResourceError, /'invalid' is not a valid IPv4 address/)

    expect {
      type_class.new({:name => 'sample', :ip_address => '127.0.0.1'})
    }.not_to raise_error
  end

  it 'should default type to ipsec.1' do
    srv = type_class.new(:name => 'sample')
    expect(srv[:type]).to eq('ipsec.1')
  end

  [
    'name',
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
