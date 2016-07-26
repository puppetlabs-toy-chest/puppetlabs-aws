require 'spec_helper'

provider_class = Puppet::Type.type(:iam_role).provider(:v2)

describe provider_class do

  before do
    ENV['AWS_ACCESS_KEY_ID'] = 'redacted'
    ENV['AWS_SECRET_ACCESS_KEY'] = 'redacted'
    ENV['AWS_REGION'] = 'sa-east-1'
  end

  context 'with the minimum params' do
    let(:resource) {
      Puppet::Type.type(:iam_role).new(
          name: 'testrole',
      )
    }

    let(:provider) { resource.provider }

    let(:instance) { provider.class.instances.first }

    it 'should be an instance of the ProviderV2' do
      expect(provider).to be_an_instance_of Puppet::Type::Iam_role::ProviderV2
    end

    describe 'self.prefetch' do
      it 'exists' do
        VCR.use_cassette('create-role') do
          provider.class.instances
          provider.class.prefetch({})
        end
      end
    end

    describe 'exists?' do
      it 'should correctly report non-existent roles' do
        VCR.use_cassette('no-role-named') do
          expect(provider.exists?).to be_falsy
        end
      end

      it 'should correctly find existing roles' do
        VCR.use_cassette('roles-named') do
          expect(instance.exists?).to be_truthy
        end
      end
    end

  end
end
