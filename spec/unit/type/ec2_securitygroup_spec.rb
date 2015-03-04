require 'spec_helper'

type_class = Puppet::Type.type(:ec2_securitygroup)

describe type_class do

  let :params do
    [
      :name,
    ]
  end

  let :properties do
    [
      :ensure,
      :description,
      :region,
      :ingress,
      :tags,
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

  it 'should order tags on output' do
    expect(type_class).to order_tags_on_output
  end

end
