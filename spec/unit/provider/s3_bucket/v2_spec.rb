require 'spec_helper'

provider_class = Puppet::Type.type(:s3_bucket).provider(:v2)


describe provider_class do

  context 'with the minimum params' do
    let(:resource) {
      Puppet::Type.type(:s3_bucket).new(
        name: 'zlesliebucketnamegoeshere',
      )
    }

    let(:provider) { resource.provider }

    let(:instance) { provider.class.instances.first }

    it 'should be an instance of the ProviderV2' do
      expect(provider).to be_an_instance_of Puppet::Type::S3_bucket::ProviderV2
    end

    describe 'self.prefetch' do
      it 'exists' do
        VCR.use_cassette('s3-bucket') do
          provider.class.instances
          provider.class.prefetch({})
        end
      end
    end

    describe 'exists?' do
      it 'should correctly report non-existent buckets' do
        VCR.use_cassette('s3-no-bucket') do
          expect(provider.exists?).to be_falsy
        end
      end

      it 'should correctly find existing buckets' do
        VCR.use_cassette('s3-bucket') do
          expect(instance.exists?).to be_truthy
        end
      end
    end

  end
end
