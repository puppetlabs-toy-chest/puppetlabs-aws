require 'spec_helper'

provider_class = Puppet::Type.type(:route53_zone).provider(:v2)

describe provider_class do

  context 'with the minimum params for a public zone' do
    let(:resource_hash) {
      {
        name: 'devopscentral.com.',
      }
    }

    let(:resource) {
      Puppet::Type.type(:route53_zone).new(resource_hash)
    }

    let(:resources) {
      {
        'devopscentral.com.' => resource,
      }
    }

    let(:provider) { resource.provider }


    it 'should be an instance of the ProviderV2' do
      expect(provider).to be_an_instance_of Puppet::Type::Route53_zone::ProviderV2
    end

    describe 'self.prefetch' do
      it 'should find nothing to prefetch' do
        VCR.use_cassette('init-zone') do
          zones = provider.class.prefetch(resources)
          expect(zones.empty?).to be_truthy
        end
      end
    end

    describe 'create' do
      it 'should create the test zone' do
        VCR.use_cassette('create-zone') do
          provider.create
          expect(provider.exists?).to be_truthy
        end
      end

      it 'should find the test zone with the correct properties after it is created' do
        VCR.use_cassette('zone-exists') do
          zones = provider.class.prefetch(resources)
          zone = zones.first
          expect(zone.exists?).to be_truthy
          expect(zone.name).to eq('devopscentral.com.')
          expect(zone.is_private).to be_falsy
          expect(zone.tags.empty?).to be_truthy
        end
      end
    end

    describe 'destory' do
      it 'should destory the test zone' do
        VCR.use_cassette('destory-zone') do
          zones = provider.class.prefetch(resources)
          zone = zones.first
          zone.destroy
          expect(zone.exists?).to be_falsy
        end
      end

      it 'should not find the test zone after it is destroyed' do
        VCR.use_cassette('zone-gone') do
          zones = provider.class.prefetch(resources)
          expect(zones.empty?).to be_truthy
        end
      end
    end
  end

end
