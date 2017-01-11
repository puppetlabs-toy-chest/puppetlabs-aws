require 'spec_helper'

provider_class = Puppet::Type.type(:iam_instance_profile).provider(:v2)

describe provider_class do

  context 'with the minimum params' do
    let(:resource) {
      Puppet::Type.type(:iam_instance_profile).new(
          name: 'test_instance_profile',
      )
    }

    let(:provider) { resource.provider }

    let(:instance) { provider.class.instances.first }

    it 'should be an instance of the ProviderV2' do
      expect(provider).to be_an_instance_of Puppet::Type::Iam_instance_profile::ProviderV2
    end

    describe 'self.prefetch' do
      it 'exists' do
        VCR.use_cassette('create-instance-profile') do
          provider.class.instances
          provider.class.prefetch({})
        end
      end
    end

    describe 'exists?' do
      it 'should correctly report non-existent instance profiles' do
        VCR.use_cassette('no-instance-profiles-named') do
          expect(provider.exists?).to be_falsy
        end
      end

      it 'should correctly find existing instance profiles' do
        VCR.use_cassette('instance-profiles-named') do
          expect(instance.exists?).to be_truthy
        end
      end
    end

  end
end
