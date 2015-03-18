require 'spec_helper'

def policy_config
  {
    name: 'scaleout',
    auto_scaling_group: 'test-asg',
    scaling_adjustment: 30,
    adjustment_type: 'PercentChangeInCapacity',
    region: 'sa-east-1',
  }
end

type_class = Puppet::Type.type(:ec2_scalingpolicy)

describe type_class do

  let :params do
    [
      :name,
    ]
  end

  let :properties do
    [
      :ensure,
      :scaling_adjustment,
      :adjustment_type,
      :region,
      :auto_scaling_group,
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

  policy_config.keys.each do |key|
    it "should require a value for #{key}" do
      modified_config = policy_config
      modified_config[key] = ''
      expect {
        type_class.new(modified_config)
      }.to raise_error(Puppet::Error)
    end
  end

  context 'with a full set of properties' do
    before :all do
      @instance = type_class.new(policy_config)
    end

    it 'should convert scaling adjustment values to an Integer' do
      expect(@instance[:scaling_adjustment].kind_of?(Integer)).to be true
    end
  end

  [
    'name',
    'region',
    'adjustment_type',
    'auto_scaling_group',
  ].each do |property|
    it "should require #{property} to be a string" do
      expect(type_class).to require_string_for(property)
    end
  end

end
