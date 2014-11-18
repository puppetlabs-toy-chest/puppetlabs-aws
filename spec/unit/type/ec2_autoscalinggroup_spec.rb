require 'spec_helper'

type_class = Puppet::Type.type(:ec2_autoscalinggroup)

describe type_class do

  let :params do
    [
      :name,
    ]
  end

  let :properties do
    [
      :ensure,
      :min_size,
      :max_size,
      :region,
      :launch_configuration,
      :instance_count,
      :availability_zones,
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
