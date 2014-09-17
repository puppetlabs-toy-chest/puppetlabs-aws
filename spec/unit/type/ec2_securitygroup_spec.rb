require 'spec_helper'

type_class = Puppet::Type.type(:ec2_securitygroup)

describe type_class do

  let :params do
    [
      :name,
      :ingress
    ]
  end

  let :properties do
    [
      :ensure,
      :description,
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
