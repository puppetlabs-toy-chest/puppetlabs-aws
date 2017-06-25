require 'spec_helper'

provider_class = Puppet::Type.type(:iam_group).provider(:v2)


describe provider_class do

  context 'with the minimum params' do
    let(:resource) {
      Puppet::Type.type(:iam_group).new(
        name: 'tgroup',
        members: [],
      )
    }

    let(:provider) { resource.provider }

    let(:instance) { provider.class.instances.first }

    it 'should be an instance of the ProviderV2' do
      expect(provider).to be_an_instance_of Puppet::Type::Iam_group::ProviderV2
    end

    describe 'self.prefetch' do
      it 'exists' do
        VCR.use_cassette('iam_group-setup') do
          provider.class.instances
          provider.class.prefetch({})
        end
      end
    end

    describe 'exists?' do
      it 'should correctly report non-existent users' do
        VCR.use_cassette('exists-iam_group') do
          expect(provider.exists?).to be_falsy
        end
      end
    end

    describe 'create' do
      it 'should make the call to create the user' do
        VCR.use_cassette('create-iam_group') do
          expect(provider.create).to be_truthy
        end
      end
    end

    describe 'destroy' do
      it 'should make the call to destroy the user' do
        VCR.use_cassette('destroy-iam_group') do
          expect(provider.destroy).to be_truthy
        end
      end
    end

  end
end

