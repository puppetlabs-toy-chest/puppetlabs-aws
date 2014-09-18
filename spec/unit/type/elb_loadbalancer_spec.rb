require 'spec_helper'

type_class = Puppet::Type.type(:elb_loadbalancer)

describe type_class do

  let :params do
    [
      :name,
      :availability_zones,
      :security_groups,
      :instances,
      :listeners
    ]
  end

  let :properties do
    [
      :ensure,
      :region
    ]
  end

  it 'should have expected properties' do
    properties.each do |property|
      type_class.properties.map(&:name).should be_include(property)
    end
  end

  it 'should have expected parameters' do
    params.each do |param|
      type_class.parameters.should be_include(param)
    end
  end
end
