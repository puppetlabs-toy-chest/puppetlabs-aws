require 'spec_helper'

type_class = Puppet::Type.type(:s3_bucket)

describe type_class do

  let :params do
    [
      :name,
    ]
  end

  let :properties do
    [
      :ensure,
      :creation_date,
      :policy,
      :lifecycle_configuration,
    ]
  end

  let :valid_attributes do
    {
      name: 'name',
      policy: '{}',
      encryption_configuration: '{}',
      lifecycle_configuration: '{}'
    }
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

  it 'should require a non-blank name' do
    expect {
      type_class.new({ name: '' })
    }.to raise_error(Puppet::Error, /Empty bucket names are not allowed/)
  end

  context 'with a valid parameters' do
    it 'should create a valid instance' do
      type_class.new(valid_attributes)
    end

    [:policy, :encryption_configuration, :lifecycle_configuration].each do |param|
      it "should create a valid instance without optional :#{param}" do
        type_class.new(valid_attributes.reject! { |k, _v| k == param })
      end

      it "should require non-blank #{param}" do
        expect {
          type_class.new(valid_attributes.merge({ param => '' }))
        }.to raise_error(Puppet::Error)
      end

      it "should fail if string is not a valid JSON #{param}" do
        expect {
          type_class.new(valid_attributes.merge({ param => '<xml>Hi</xml>' }))
        }.to raise_error(Puppet::Error)
      end

      it "should accept any valid JSON #{param}" do
          type_class.new(valid_attributes.merge({ param => '{ "hello": "world!" }' }))
      end

    end
  end

end


