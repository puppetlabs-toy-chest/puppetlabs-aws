require 'spec_helper'

type_class = Puppet::Type.type(:elb_loadbalancer)

def elb_config
  {
    name: 'lb-1',
    availability_zones: ['sa-east-1a'],
    instances: ['web-1', 'web-2'],
    listeners: [{
      'protocol' => 'tcp',
      'load_balancer_port' => 80,
      'instance_protocol' => 'tcp',
      'instance_port' => 80,
    }],
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
      :ensure,
      :region,
      :availability_zones,
      :instances,
      :listeners,
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

  it 'should require a name' do
    expect {
      type_class.new({})
    }.to raise_error(Puppet::Error, 'Title or name must be provided')
  end

  it "should require a region without a space" do
    expect {
      type_class.new({:name => 'sample', :region => 'invalid region'})
    }.to raise_error(Puppet::Error)
  end

  it 'should order tags on output' do
    tags = {'b' => 1, 'a' => 2}
    reverse = {'a' => 2, 'b' => 1}
    elb = type_class.new(:name => 'sample', :tags => tags )
    expect(elb.property(:tags).insync?(tags)).to be true
    expect(elb.property(:tags).insync?(reverse)).to be true
    expect(elb.property(:tags).should_to_s(tags).to_s).to eq(reverse.to_s)
  end

  it "should require a non-empty valid listener" do
    expect {
      type_class.new({:name => 'sample', :listener => []})
    }.to raise_error(Puppet::Error)
  end

  it "should require a valid listener" do

    valid_listener = {
      'protocol' => 'tcp',
      'load_balancer_port' => 80,
      'instance_protocol' => 'tcp',
      'instance_port' => 80,
    }

    valid_listener.keys.each do |key|
      listener = valid_listener.tap { |inner| inner.delete(key) }
      expect {
        type_class.new({:name => 'sample', :listener => [listener]})
      }.to raise_error(Puppet::Error)
    end
  end

  it 'with a valid config it should not error' do
    expect { type_class.new(elb_config) }.to_not raise_error
  end

  it 'should normalise listener information' do
    elb = type_class.new(elb_config)
    expect(elb.property(:listeners).insync?([{
      'protocol' => 'TCP',
      'load_balancer_port' => '80',
      'instance_protocol' => 'TCP',
      'instance_port' => '80',
    }])).to be true
  end

end
