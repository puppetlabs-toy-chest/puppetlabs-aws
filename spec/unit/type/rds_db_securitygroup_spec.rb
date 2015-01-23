require 'spec_helper'

type_class = Puppet::Type.type(:rds_db_securitygroup)

describe type_class do

  let :params do
    [
      :name,
      :db_security_group_description,
    ]
  end

  let :properties do
    [
      :owner_id,
      :ec2_security_groups,
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