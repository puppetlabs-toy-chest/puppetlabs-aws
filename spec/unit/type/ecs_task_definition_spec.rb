require 'spec_helper'

type_class = Puppet::Type.type(:ecs_task_definition)

describe type_class do
  let :params do
    [
      :name,
      :replace_image,
    ]
  end

  let :properties do
    [
      :arn,
      :revision,
      :volumes,
      :container_definitions,
      :role,
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
