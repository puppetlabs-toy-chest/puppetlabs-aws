require 'spec_helper'

provider_class = Puppet::Type.type(:route53_a_record).provider(:v2)

ENV['AWS_ACCESS_KEY_ID'] = 'redacted'
ENV['AWS_SECRET_ACCESS_KEY'] = 'redacted'
ENV['AWS_REGION'] = 'sa-east-1'

describe provider_class do

  context 'with the minimum params' do
    let(:resource) { Puppet::Type.type(:route53_a_record).new(
      name: 'local.devopscentral.com.',
      zone: 'devopscentral.com.',
      ttl: 3000,
      values: ['127.0.0.1']
    )}

    let(:provider) { resource.provider }

    let(:instance) { provider.class.instances.first }

    it 'should be an instance of the ProviderV2' do
      expect(provider).to be_an_instance_of Puppet::Type::Route53_a_record::ProviderV2
    end

    describe 'self.prefetch' do
      it 'exists' do
        VCR.use_cassette('record-setup') do
          provider.class.instances
          provider.class.prefetch({})
        end
      end
    end

    describe 'exists?' do
      it 'should correctly report non-existent records' do
        VCR.use_cassette('no-record-named') do
          expect(provider.exists?).to be_falsy
        end
      end

      it 'should correctly find existing records' do
        VCR.use_cassette('record-named') do
          expect(instance.exists?).to be_truthy
        end
      end
    end

    describe 'create' do
      it 'should send a request to the EC2 API to create the record' do
        VCR.use_cassette('create-record') do
          expect(provider.create).to be_truthy
        end
      end
    end

    describe 'destroy' do
      it 'should send a request to the EC2 API to destroy the record' do
        VCR.use_cassette('destroy-record') do
          expect(provider.destroy).to be_truthy
        end
      end
    end

  end

end
