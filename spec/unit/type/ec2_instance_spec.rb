require 'spec_helper'

type_class = Puppet::Type.type(:ec2_instance)

describe type_class do

  let :params do
    [
      :name,
      :security_groups
    ]
  end

  let :properties do
    [
      :ensure,
      :image_id,
      :instance_type,
      :region,
      :availability_zone,
      :monitoring,
      :key_name,
      :subnet,
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
