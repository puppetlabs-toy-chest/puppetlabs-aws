require 'spec_helper'

type_class = Puppet::Type.type(:cloudwatch_alarm)

describe type_class do

  let :params do
    [
      :name,
      :dimensions,
      :alarm_actions
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
