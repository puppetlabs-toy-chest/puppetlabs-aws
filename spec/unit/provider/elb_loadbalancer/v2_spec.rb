require 'spec_helper'

provider_class = Puppet::Type.type(:elb_loadbalancer).provider(:v2)

ENV['AWS_ACCESS_KEY_ID'] = 'redacted'
ENV['AWS_SECRET_ACCESS_KEY'] = 'redacted'
ENV['AWS_REGION'] = 'sa-east-1'

describe provider_class do

  context 'with the minimum params' do
    let(:resource) {
      Puppet::Type.type(:elb_loadbalancer).new(
        name: 'lb-1',
        instances: ['web-1'],
        listeners: [],
        availability_zones: ['sa-east-1a'],
        region: 'sa-east-1',
      )
    }

    let(:provider) { resource.provider }

    let(:instance) { provider.class.instances.first }

    it 'should be an instance of the ProviderV2' do
      expect(provider).to be_an_instance_of Puppet::Type::Elb_loadbalancer::ProviderV2
    end

    describe 'self.prefetch' do
      it 'exists' do
        VCR.use_cassette('elb-setup') do
          provider.class.instances
          provider.class.prefetch({})
        end
      end
    end

    describe 'exists?' do
      it 'should correctly report non-existent load balancers' do
        VCR.use_cassette('no-elb-named-test') do
          expect(provider.exists?).to be_falsy
        end
      end

      it 'should correctly find existing load balancers' do
        VCR.use_cassette('elb-named-test') do
          expect(instance.exists?).to be_truthy
        end
      end
    end

    describe 'create' do
      it 'should send a request to the ELB API to create the load balancer' do
        VCR.use_cassette('create-elb-test') do
          expect(provider.create).to be_truthy
        end
      end
    end

    describe 'destroy' do
      it 'should send a request to the ELB API to destroy the load balancer' do
        VCR.use_cassette('destroy-elb-test') do
          expect(provider.destroy).to be_truthy
        end
      end
    end

  end

end
