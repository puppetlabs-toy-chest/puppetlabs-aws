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
end