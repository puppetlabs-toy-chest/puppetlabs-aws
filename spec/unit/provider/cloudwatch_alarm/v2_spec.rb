require 'spec_helper'

provider_class = Puppet::Type.type(:cloudwatch_alarm).provider(:v2)

ENV['AWS_ACCESS_KEY_ID'] = 'redacted'
ENV['AWS_SECRET_ACCESS_KEY'] = 'redacted'
ENV['AWS_REGION'] = 'sa-east-1'

describe provider_class do

  let(:resource) {
    Puppet::Type.type(:cloudwatch_alarm).new(
      name: 'AddCapacity',
      metric: 'CPUUtilization',
      namespace: 'AWS/EC2',
      statistic: 'Average',
      period: 120,
      threshold: 60,
      comparison_operator: 'GreaterThanOrEqualToThreshold',
      evaluation_periods: 2,
      region: 'sa-east-1',
    )
  }

  let(:provider) { resource.provider }

  let(:instance) { provider.class.instances.first }

  it 'should be an instance of the ProviderV2' do
    expect(provider).to be_an_instance_of Puppet::Type::Cloudwatch_alarm::ProviderV2
  end

  describe 'self.prefetch' do
    it 'should exist' do
      VCR.use_cassette('alarm-setup') do
        provider.class.instances
        provider.class.prefetch({})
      end
    end
  end

  context 'with the minimum params' do

    describe 'running exists?' do
      it 'should correctly report non-existent alarms' do
        VCR.use_cassette('no-alarm-with-name') do
          expect(provider.exists?).to be_falsy
        end
      end

      it 'should correctly find existing alarms' do
        VCR.use_cassette('alarm-with-name') do
          expect(instance.exists?).to be_truthy
        end
      end
    end

    describe 'running create' do
      it 'should send a request to the Cloudwatch API to create the alarm' do
        VCR.use_cassette('create-alarm') do
          expect(provider.create).to be_truthy
        end
      end
    end

    describe 'running destroy' do
      it 'should send a request to the Cloudwatch API to destroy the alarm' do
        VCR.use_cassette('destroy-alarm') do
          expect(provider.destroy).to be_truthy
        end
      end
    end

  end

end
