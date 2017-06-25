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
      :security_groups,
      :subnets,
      :scheme,
      :dns_name,
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
    expect(type_class).to order_tags_on_output
  end

  it "should require a non-empty valid listener" do
    expect {
      type_class.new({:name => 'sample', :listener => []})
    }.to raise_error(Puppet::Error)
  end

  context 'when validating a listener' do
    context 'with all required keys are met' do
      it 'should not fail' do
        valid_listener = {
          'protocol' => 'https',
          'load_balancer_port' => 443,
          'instance_protocol' => 'tcp',
          'instance_port' => 80,
        }

        expect {
          type_class.new({:name => 'sample', :listener => [valid_listener]})
        }.to raise_error(Puppet::Error)
      end
    end

    context 'when not all requried keys are met' do
      it 'should fail' do
        valid_listener = {
          'protocol' => 'https',
          'load_balancer_port' => 443,
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
    end

    context 'with https listener' do
      it 'should raise an error when no ssl_certificate_id is present' do
        invalid_listener = {
          'protocol' => 'https',
          'load_balancer_port' => 443,
          'instance_protocol' => 'tcp',
          'instance_port' => 80,
        }

        expect {
          type_class.new(:name => 'sample', :listeners => [invalid_listener])
        }.to raise_error(Puppet::Error)

      end

      it 'should not raise an error when ssl_certificate_id is present' do

        valid_listener = {
          'protocol' => 'https',
          'load_balancer_port' => 443,
          'instance_protocol' => 'tcp',
          'instance_port' => 80,
          'ssl_certificate_id' => 'something/made/up'
        }

        type_class.new(:name => 'sample', :listeners => [valid_listener])

        expect {
          type_class.new(:name => 'sample', :listeners => [valid_listener])
        }.to_not raise_error
      end
    end

    context 'when validating a listener policy' do
      context 'a correct policy type is used' do
        let(:listener) {
          {
            'protocol' => 'https',
            'load_balancer_port' => 443,
            'instance_protocol' => 'tcp',
            'instance_port' => 80,
            'ssl_certificate_id' => 'something/made/up',
            'policies' => [
              {
                'SSLNegotiationPolicyType' => {
                  'Protocol-TLSv1.1' => true,
                }
              }
            ]
          }
        }

        it 'should validate' do
          VCR.use_cassette('elb_loadbalancer-policy-types') do
            expect {
              type_class.new(:name => 'sample', :listeners => [listener])
            }.to_not raise_error
          end
        end

        context 'with invalid policy_attribtues' do
          let(:listener) {
            {
              'protocol' => 'https',
              'load_balancer_port' => 443,
              'instance_protocol' => 'tcp',
              'instance_port' => 80,
              'ssl_certificate_id' => 'something/made/up',
              'policies' => [
                {
                  'SSLNegotiationPolicyType' => {
                    'Protocol-TLSv0.9' => true,
                  }
                }
              ]
            }
          }

          it 'shoud not validate' do
            VCR.use_cassette('elb_loadbalancer-policy-types') do
              expect {
                type_class.new(:name => 'sample', :listeners => [listener])
              }.to raise_error(Puppet::Error, /Invalid attribute/)
            end
          end
        end
        context 'with valid policy_attribtues' do
          let(:listener) {
            {
              'protocol' => 'https',
              'load_balancer_port' => 443,
              'instance_protocol' => 'tcp',
              'instance_port' => 80,
              'ssl_certificate_id' => 'something/made/up',
              'policies' => [
                {
                  'SSLNegotiationPolicyType' => {
                    'Protocol-TLSv1.1' => true,
                    'Protocol-TLSv1.2' => true,
                  }
                }
              ]
            }
          }
          it 'shoud validate' do
            VCR.use_cassette('elb_loadbalancer-policy-types') do
              expect {
                type_class.new(:name => 'sample', :listeners => [listener])
              }.to_not raise_error
            end
          end
        end
      end

      context 'when an invalid policy type is set' do
        let(:listener) {
          {
            'protocol' => 'https',
            'load_balancer_port' => 443,
            'instance_protocol' => 'tcp',
            'instance_port' => 80,
            'ssl_certificate_id' => 'something/made/up',
            'policies' => [
              {
                'SSLNegotiationPolicyTypo' => {
                  'Protocol-TLSv1.1' => true,
                }
              }
            ]
          }
        }

        it 'should fail to validate' do
          VCR.use_cassette('elb_loadbalancer-policy-types') do
            expect {
              type_class.new(:name => 'sample', :listeners => [listener])
            }.to raise_error(Puppet::Error, /Invalid policy type/)
          end
        end

      end
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

  it 'should not have a default for subnets' do
    elb = type_class.new({:name => 'sample'})
    expect(elb[:subnets]).to eq(nil)
  end

  it 'should not have a default for availability zones' do
    elb = type_class.new({:name => 'sample'})
    expect(elb[:availability_zones]).to eq(nil)
  end

  it 'should default scheme to public' do
    elb = type_class.new({:name => 'sample'})
    expect(elb[:scheme]).to eq(:'internet-facing')
  end

  it 'should not allow invalid values for scheme' do
    expect {
      type_class.new({:name => 'sample', :scheme => 'invalid'})
    }.to raise_error(Puppet::Error)
  end

  it 'should allow valid values for scheme' do
    elb = type_class.new({:name => 'sample', :scheme => 'internal'})
    expect(elb[:scheme]).to eq(:internal)
  end

  ['instances', 'subnets', 'security_groups'].each do |property|
    it "should ignore the order of #{property} for matching" do
      values = ['a', 'b']
      config = {:name => 'sample'}
      config[property.to_sym] = values
      elb = type_class.new(config)
      expect(elb.property(property.to_sym).insync?(values)).to be true
      expect(elb.property(property.to_sym).insync?(values.reverse)).to be true
    end
  end

  it "should disallow passing both a subnet and an availability zone" do
    expect {
      type_class.new({:name => 'sample', :subnets => ['subnet'], :availability_zones => ['zones']})
    }.to raise_error(Puppet::Error)
  end

  [
    'name',
    'region',
    'security_groups',
    'instances',
    'subnets',
  ].each do |property|
    it "should require #{property} to be a string" do
      expect(type_class).to require_string_for(property)
    end
  end

  it "should require tags to be a hash" do
    expect(type_class).to require_hash_for('tags')
  end
end
