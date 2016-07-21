require 'spec_helper'

provider_class = Puppet::Type.type(:iam_user).provider(:v2)

ENV['AWS_ACCESS_KEY_ID'] = 'redacted'
ENV['AWS_SECRET_ACCESS_KEY'] = 'redacted'
ENV['AWS_REGION'] = 'sa-east-1'

describe provider_class do

  context 'with the minimum params' do
    let(:resource) {
      Puppet::Type.type(:iam_user).new(
        name: 'zleslie2',
      )
    }

    let(:provider) { resource.provider }

    let(:instance) { provider.class.instances.first }

    it 'should be an instance of the ProviderV2' do
      expect(provider).to be_an_instance_of Puppet::Type::Iam_user::ProviderV2
    end

    describe 'self.prefetch' do
      it 'exists' do
        VCR.use_cassette('create-user') do
          provider.class.instances
          provider.class.prefetch({})
        end
      end
    end

    describe 'exists?' do
      it 'should correctly report non-existent users' do
        VCR.use_cassette('no-user-named') do
          expect(provider.exists?).to be_falsy
        end
      end

      it 'should correctly find existing users' do
        VCR.use_cassette('users-named') do
          expect(instance.exists?).to be_truthy
        end
      end
    end

  end
end
