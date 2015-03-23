require 'spec_helper'

type_class = Puppet::Type.type(:cloudwatch_alarm)

def alarm_config
  {
    name: 'AddCapacity',
    metric: 'CPUUtilization',
    namespace: 'AWS/EC2',
    statistic: 'Average',
    period: 120,
    threshold: 60,
    comparison_operator: 'GreaterThanOrEqualToThreshold',
    evaluation_periods: 2,
    region: 'sa-east-1',
  }
end

describe type_class do

  let :params do
    [
      :name,
    ]
  end

  let :properties do
    [
      :evaluation_periods,
      :threshold,
      :comparison_operator,
      :region,
      :namespace,
      :metric,
      :statistic,
      :period,
      :dimensions,
      :alarm_actions
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

  alarm_config.keys.each do |key|
    it "should require a value for #{key}" do
      modified_config = alarm_config
      modified_config[key] = ''
      expect {
        type_class.new(modified_config)
      }.to raise_error(Puppet::Error)
    end
  end

  [
    'metric',
    'namespace',
    'statistic',
    'comparison_operator',
    'region',
    'alarm_actions',
  ].each do |property|
    it "should require #{property} to be a string" do
      expect(type_class).to require_string_for(property)
    end
  end

  it "should require dimensions to be a hash" do
    expect(type_class).to require_hash_for('dimensions')
  end

  context 'with a full set of properties' do
    before :all do
      @instance = type_class.new(alarm_config)
    end

    it 'should convert threshold values to a float' do
      expect(@instance[:threshold].kind_of?(Float)).to be true
    end

    it 'should convert period values to an integer' do
      expect(@instance[:period].kind_of?(Integer)).to be true
    end

    it 'should convert evaluation period values to an integer' do
      expect(@instance[:evaluation_periods].kind_of?(Integer)).to be true
    end

  end

end
