require 'spec_helper'

type_class = Puppet::Type.type(:ec2_vpc_subnet)

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
      :region,
      :availability_zone,
      :vpc,
      :id,
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

  [
    'name',
    'region',
    'vpc',
    'cidr_block',
    'availability_zone',
    'route_table',
  ].each do |property|
    it "should require #{property} to be a string" do
      expect(type_class).to require_string_for(property)
    end
  end

  it "should require tags to be a hash" do
    expect(type_class).to require_hash_for('tags')
  end

  it 'should default to not providing a public ip' do
    subnet = type_class.new({:name => 'sample'})
    expect(subnet[:map_public_ip_on_launch]).to eq(:false)
  end

  it 'should not allow invalid values for scheme' do
    expect {
      type_class.new({:name => 'sample', :map_public_ip_on_launch => 'invalid'})
    }.to raise_error(Puppet::Error)
  end

  it 'should allow valid values for scheme' do
    subnet = type_class.new({:name => 'sample', :map_public_ip_on_launch => true})
    expect(subnet[:map_public_ip_on_launch]).to eq(:true)
  end

end
