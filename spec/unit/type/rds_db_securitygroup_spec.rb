require 'spec_helper'

type_class = Puppet::Type.type(:rds_db_securitygroup)

describe type_class do

  let :params do
    [
      :name,
    ]
  end

  let :properties do
    [
      :owner_id,
      :security_groups,
      :region,
      :ip_ranges,
      :description,
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

  it 'should require a value for description' do
    expect {
      type_class.new({:name => 'sample', :description => ''})
    }.to raise_error(Puppet::Error, /description should not be blank/)
  end

  it 'should require a valid looking region' do
    expect {
      type_class.new({:name => 'sample', :region => 'definitely invalid'})
    }.to raise_error(Puppet::Error, /region should be a valid AWS region/)
  end

  [
    'name',
    'region',
    'description',
  ].each do |property|
    it "should require #{property} to be a string" do
      expect(type_class).to require_string_for(property)
    end
  end

  [
    :security_groups,
    :ip_ranges,
    :owner_id,
  ].each do |property|
    it "should have a read-only property of #{property}" do
      expect {
        config = {:name => 'sample'}
        config[property] = 'present'
        type_class.new(config)
      }.to raise_error(Puppet::Error, /#{property} is read-only/)
    end
  end
end
