require 'spec_helper'

type_class = Puppet::Type.type(:ec2_vpc_dhcp_options)

describe type_class do

  let :params do
    [
      :name,
    ]
  end

  let :properties do
    [
      :ensure,
      :tags,
      :region,
      :domain_name,
      :domain_name_servers,
      :ntp_servers,
      :netbios_name_servers,
      :netbios_node_type,
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

  ['8.8.8.8','2.2.2.2'].each do |value|
    it 'require netbios node type when netbios name server is used' do
      expect{
        type_class.new(:name => 'sample', :netbios_name_servers => value)
      }.to raise_error(Puppet::ResourceError, /You must specify netbios node type, when using netbios name server.Recommended value is 2/)
    end
  end

  it 'compare a list of domain names with an array correctly' do
    domains = ['valid1', 'valid2']
    set = type_class.new(:name => 'sample', :domain_name => domains)
    expect(set.property(:domain_name).insync?(domains.reverse)).to be true
  end

  it 'should spot invalid domain names' do
    expect {
      type_class.new(:name => 'sample', :domain_name => 'inval id')
    }.to raise_error(Puppet::ResourceError, /is not a valid domain_name/)
  end

  it 'should spot invalid domain names in lists' do
    expect {
      type_class.new(:name => 'sample', :domain_name => ['valid', 'inval id'])
    }.to raise_error(Puppet::ResourceError, /is not a valid domain_name/)
  end

  [1,2,4,8].each do |value|
    it "should be able to set node type to a valid value of #{value}" do
      expect {
        type_class.new(:name => 'sample', :netbios_node_type => value)
      }.to_not raise_error
    end
  end

  ['invalid', 3].each do |value|
    it "should not be able to set node type to invalid values like #{value}" do
      expect {
        type_class.new(:name => 'sample', :netbios_node_type => value)
      }.to raise_error(Puppet::ResourceError)
    end
  end

  [
    'name',
    'region',
    'ntp_servers',
    'domain_name_servers',
    'netbios_name_servers',
  ].each do |property|
    it "should require #{property} to be a string" do
      expect(type_class).to require_string_for(property)
    end
  end

  it "should require tags to be a hash" do
    expect(type_class).to require_hash_for('tags')
  end

end
