require 'spec_helper'

provider_class = Puppet::Type.type(:ec2_scalingpolicy).provider(:v2)


describe provider_class do

  let(:resource) {
    Puppet::Type.type(:ec2_scalingpolicy).new(
      name: 'scalein',
      auto_scaling_group: 'test-asg',
      scaling_adjustment: 30,
      adjustment_type: 'PercentChangeInCapacity',
      region: 'sa-east-1',
    )
  }

  let(:provider) { resource.provider }

  let(:instance) { provider.class.instances.first }

  it 'should be an instance of the ProviderV2' do
    expect(provider).to be_an_instance_of Puppet::Type::Ec2_scalingpolicy::ProviderV2
  end

  describe 'self.prefetch' do
    it 'should exist' do
      VCR.use_cassette('policy-setup') do
        provider.class.instances
        provider.class.prefetch({})
      end
    end
  end

  context 'with the minimum params' do

    describe 'running exists?' do
      it 'should correctly report non-existent scaling policies' do
        VCR.use_cassette('no-policy-with-name') do
          expect(provider.exists?).to be_falsy
        end
      end

      it 'should correctly find existing scaling policies' do
        VCR.use_cassette('policy-with-name') do
          expect(instance.exists?).to be_truthy
        end
      end
    end

    describe 'running create' do
      it 'should send a request to the EC2 API to create the policy' do
        VCR.use_cassette('create-policy') do
          expect(provider.create).to be_truthy
        end
      end
    end

    describe 'running destroy' do
      it 'should send a request to the EC2 API to destroy the policy' do
        VCR.use_cassette('destroy-policy') do
          expect(provider.destroy).to be_truthy
        end
      end
    end

  end

end
