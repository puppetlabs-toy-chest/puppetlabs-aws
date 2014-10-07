require 'spec_helper'

provider_class = Puppet::Type.type(:route53_zone).provider(:v2)

ENV['AWS_ACCESS_KEY_ID'] = 'redacted'
ENV['AWS_SECRET_ACCESS_KEY'] = 'redacted'
ENV['AWS_REGION'] = 'sa-east-1'

describe provider_class do

  context 'with the minimum params' do
    let(:resource) { Puppet::Type.type(:route53_zone).new(
      name: 'devopscentral.com.',
    )}

    let(:provider) { resource.provider }

    let(:instance) { provider.class.instances.first }

    it 'should be an instance of the ProviderV2' do
      expect(provider).to be_an_instance_of Puppet::Type::Route53_zone::ProviderV2
    end

    describe 'self.prefetch' do
      it 'exists' do
        VCR.use_cassette('zone-setup') do
          provider.class.instances
          provider.class.prefetch({})
        end
      end
    end

    describe 'exists?' do
      it 'should correctly report non-existent zones' do
        VCR.use_cassette('no-zone-named') do
          expect(provider.exists?).to be_falsy
        end
      end

      it 'should correctly find existing zones' do
        VCR.use_cassette('zone-named') do
          expect(instance.exists?).to be_truthy
        end
      end
    end

    describe 'create' do
      it 'should send a request to the EC2 API to create the zone' do
        VCR.use_cassette('create-zone') do
          expect(provider.create).to be_truthy
        end
      end
    end

    describe 'destroy' do
      it 'should send a request to the EC2 API to destroy the zone' do
        VCR.use_cassette('destroy-zone') do
          expect(provider.destroy).to be_truthy
        end
      end
    end

  end

end
