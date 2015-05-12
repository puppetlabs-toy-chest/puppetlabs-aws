require 'spec_helper'

type_class = Puppet::Type.type(:rds_instance)

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
      :engine,
      :engine_version,
      :license_model,
      :allocated_storage,
      :availability_zone,
      :storage_type,
      :db_instance_class,
      :master_username,
      :master_user_password,
      :multi_az,
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

  it 'IOPS must be an integer' do
    expect {
      type_class.new(:name => 'sample', :iops => 'Ten')
    }.to raise_error(Puppet::ResourceError, /The value of the IOPS must be an integer/)
  end

  it 'should default skip_final_snapshot to false' do
    rds_srv = type_class.new(:name => 'sample')
    expect(rds_srv[:skip_final_snapshot]).to eq(:true)
  end

  [
    'region',
    'db_instance_class',
    'availability_zone',
  ].each do |property|
    it "should require #{property} to be a string" do
      expect(type_class).to require_string_for(property)
    end
  end

end