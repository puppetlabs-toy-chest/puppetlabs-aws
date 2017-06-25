require 'spec_helper'

provider_class = Puppet::Type.type(:ec2_elastic_ip).provider(:v2)


describe provider_class do

  context 'with the minimum params' do
    let(:resource) { Puppet::Type.type(:ec2_elastic_ip).new(
      name: '177.71.189.57',
      region: 'sa-east-1',
      instance: 'web-1',
    )}

    let(:provider) { resource.provider }

    let(:instance) { provider.class.instances.first }

    it 'should be an instance of the ProviderV2' do
      expect(provider).to be_an_instance_of Puppet::Type::Ec2_elastic_ip::ProviderV2
    end

    describe 'self.prefetch' do
      it 'exists' do
        VCR.use_cassette('ip-setup') do
          provider.class.instances
          provider.class.prefetch({})
        end
      end
    end

    describe 'exists?' do
      it 'should correctly report non-existent Elastic IP addresses' do
        VCR.use_cassette('no-ip-named') do
          expect(provider.exists?).to be_falsy
        end
      end

      it 'should correctly find existing Elastic IP addresses' do
        VCR.use_cassette('ip-named') do
          expect(instance.exists?).to be_truthy
        end
      end
    end

    describe 'create' do
      it 'should send a request to the EC2 API to create the association' do
        VCR.use_cassette('create-ip') do
          expect(provider.create).to be_truthy
        end
      end
    end

    describe 'destroy' do
      it 'should send a request to the EC2 API to destroy the association' do
        VCR.use_cassette('destroy-ip') do
          expect(provider.destroy).to be_truthy
        end
      end
    end

  end

end
