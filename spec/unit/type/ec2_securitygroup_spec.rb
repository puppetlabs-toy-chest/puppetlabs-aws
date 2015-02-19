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
    tags = {'b' => 1, 'a' => 2}
    reverse = {'a' => 2, 'b' => 1}
    srv = type_class.new(:name => 'sample', :tags => tags )
    expect(srv.property(:tags).insync?(tags)).to be true
    expect(srv.property(:tags).insync?(reverse)).to be true
    expect(srv.property(:tags).should_to_s(tags).to_s).to eq(reverse.to_s)
  end

end
