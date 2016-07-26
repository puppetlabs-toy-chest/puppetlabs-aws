require 'spec_helper'

type_class = Puppet::Type.type(:iam_role)

describe type_class do

  before do
    ENV['AWS_ACCESS_KEY_ID'] = 'redacted'
    ENV['AWS_SECRET_ACCESS_KEY'] = 'redacted'
    ENV['AWS_REGION'] = 'sa-east-1'
  end

  let :params do
    [
        :name,
    ]
  end

  let :properties do
    [
        :ensure,
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

  it 'should require a name' do
    expect {
      type_class.new({})
    }.to raise_error(Puppet::Error, 'Title or name must be provided')
  end

  context 'with a valid name' do
    it 'should create a valid instance' do
      type_class.new({ name: 'name' })
    end
  end

end

