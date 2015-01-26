require 'spec_helper'

provider_class = Puppet::Type.type(:ec2_autoscalinggroup).provider(:v2)

ENV['AWS_ACCESS_KEY_ID'] = 'redacted'
ENV['AWS_SECRET_ACCESS_KEY'] = 'redacted'
ENV['AWS_REGION'] = 'sa-east-1'

describe provider_class do

  let(:resource) {
    Puppet::Type.type(:ec2_autoscalinggroup).new(
      name: 'test-asg',
      max_size: 2,
      min_size: 1,
      launch_configuration: 'test-lc',
      availability_zones: ['sa-east-1a'],
      region: 'sa-east-1',
    )
  }

  let(:provider) { resource.provider }

  let(:instance) { provider.class.instances.first }

  it 'should be an instance of the ProviderV2' do
    expect(provider).to be_an_instance_of Puppet::Type::Ec2_autoscalinggroup::ProviderV2
  end

  describe 'self.prefetch' do
    it 'should exist' do
      VCR.use_cassette('asg-setup') do
        provider.class.instances
        provider.class.prefetch({})
      end
    end
  end

  context 'with the minimum params' do

    describe 'running exists?' do
      it 'should correctly report non-existent autoscaling group' do
        VCR.use_cassette('no-asg-with-name') do
          expect(provider.exists?).to be_falsy
        end
      end

      it 'should correctly find existing autoscaling groups' do
        VCR.use_cassette('asg-with-name') do
          expect(instance.exists?).to be_truthy
        end
      end
    end

    describe 'running create' do
      it 'should send a request to the EC2 API to create the autoscaling group' do
        VCR.use_cassette('create-asg') do
          expect(provider.create).to be_truthy
        end
      end
    end

    describe 'running destroy' do
      it 'should send a request to the EC2 API to destroy the autoscaling group' do
        VCR.use_cassette('destroy-asg') do
          expect(provider.destroy).to be_truthy
        end
      end
    end

  end

end
