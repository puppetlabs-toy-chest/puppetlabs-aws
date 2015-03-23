require 'spec_helper'

def launchconfig_config
  {
    name: 'test-lc',
    image_id: 'ami-67a60d7a',
    instance_type: 't1.micro',
    region: 'sa-east-1',
    security_groups: ['test-sg'],
  }
end

type_class = Puppet::Type.type(:ec2_launchconfiguration)

describe type_class do

  let :params do
    [
      :name,
      :user_data,
      :vpc,
    ]
  end

  let :properties do
    [
      :ensure,
      :region,
      :security_groups,
      :instance_type,
      :image_id,
      :key_name,
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

  launchconfig_config.keys.each do |key|
    it "should require a value for #{key}" do
      modified_config = launchconfig_config
      modified_config[key] = ''
      expect {
        type_class.new(modified_config)
      }.to raise_error(Puppet::Error)
    end
  end

  context 'with a full set of properties' do
    it 'should successfully instantiate' do
      type_class.new(launchconfig_config)
    end
  end

  [
    'name',
    'security_groups',
    'key_name',
    'region',
    'instance_type',
    'image_id',
    'vpc',
  ].each do |property|
    it "should require #{property} to be a string" do
      expect(type_class).to require_string_for(property)
    end
  end

end
