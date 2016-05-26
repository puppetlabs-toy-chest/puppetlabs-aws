require 'spec_helper'

type_class = Puppet::Type.type(:rds_instance)

describe type_class do

  let :params do
    [
      :name,
      :master_user_password,
      :skip_final_snapshot,
      :final_db_snapshot_identifier,
    ]
  end

  let :properties do
    [
      :ensure,
      :region,
      :db_name,
      :db_instance_class,
      :availability_zone,
      :engine,
      :engine_version,
      :allocated_storage,
      :license_model,
      :storage_type,
      :iops,
      :master_username,
      :multi_az,
      :db_security_groups,
      :vpc_security_groups,
      :endpoint,
      :port,
      :db_parameter_group,
      :backup_retention_period,
      :db_subnet,
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
    }.to raise_error(Puppet::ResourceError, /IOPS must be an integer/)
  end

  it 'should default skip_final_snapshot to false' do
    srv = type_class.new(:name => 'sample')
    expect(srv[:skip_final_snapshot]).to eq(:false)
  end

  it 'should default multi_az to false' do
    srv = type_class.new(:name => 'sample')
    expect(srv[:multi_az]).to eq(:false)
  end

  [
    'name',
    'region',
    'db_instance_class',
    'availability_zone',
    'engine',
    'engine_version',
    'license_model',
    'storage_type',
    'master_username',
    'master_user_password',
    :db_parameter_group,
    'final_db_snapshot_identifier',
  ].each do |property|
    it "should require #{property} to be a string" do
      expect(type_class).to require_string_for(property)
    end
  end

  [
    :endpoint,
    :port,
  ].each do |property|
    it "should have a read-only property of #{property}" do
      expect {
        config = {:name => 'sample'}
        config[property] = 'present'
        type_class.new(config)
      }.to raise_error(Puppet::Error, /#{property} is read-only/)
    end
  end

  it 'backup_retention_period must be an integer' do
    expect {
      type_class.new(:name => 'sample', :backup_retention_period => 'Ten')
    }.to raise_error(Puppet::ResourceError, /backup_retention_period must be an integer/)
  end

  context 'with the backup_retention_period set to an integer' do
    let(:machine) { type_class.new(:name => 'sample', :backup_retention_period => 40) }

    it 'should be happy with strings for backup_retention_period' do
      expect(machine.property(:backup_retention_period).insync?('40')).to be true
    end

    it 'should be happy with integers for backup_retention_period' do
      expect(machine.property(:backup_retention_period).insync?(40)).to be true
    end
  end

  it 'should default backup_retention_period to 30' do
    srv = type_class.new(:name => 'sample')
    expect(srv[:backup_retention_period]).to eq(30)
  end

  it 'allocated_storage must be an integer' do
    expect {
      type_class.new(:name => 'sample', :allocated_storage => 'Ten')
    }.to raise_error(Puppet::ResourceError, /allocated_storage must be an integer/)
  end

  context 'with the allocated_storage set to an integer' do
    let(:machine) { type_class.new(:name => 'sample', :allocated_storage => 40) }

    it 'should be happy with strings for allocated_storage' do
      expect(machine.property(:allocated_storage).insync?('40')).to be true
    end

    it 'should be happy with integers for allocated_storage' do
      expect(machine.property(:allocated_storage).insync?(40)).to be true
    end
  end
end
