require 'spec_helper'

type_class = Puppet::Type.type(:ec2_vpc_vpn_gateway)

describe type_class do

  let :params do
    [
      :name,
    ]
  end

  let :properties do
    [
      :ensure,
      :tags,
      :vpc,
      :type,
      :region,
      :availability_zone,
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
