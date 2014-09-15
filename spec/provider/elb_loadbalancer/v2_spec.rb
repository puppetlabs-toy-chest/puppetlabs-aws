require 'spec_helper'

provider_class = Puppet::Type.type(:elb_loadbalancer).provider(:v2)

ENV['AWS_ACCESS_KEY_ID'] = 'redacted'
ENV['AWS_SECRET_ACCESS_KEY'] = 'redacted'

describe provider_class do

  context 'with the minimum params' do
    before(:each) do
      @resource = Puppet::Type.type(:elb_loadbalancer).new(
        name: 'test',
        instances: [],
        listeners: [],
        security_groups: [],
        availability_zones: []
      )
      @provider = provider_class.new(@resource)
    end

    it 'should be an instance of the ProviderV2' do
      @provider.should be_an_instance_of Puppet::Type::Elb_loadbalancer::ProviderV2
    end

    context 'exists?' do
      it 'should correctly report non-existent load balancers' do
        VCR.use_cassette('no-elb-named-test') do
          @provider.exists?.should be false
        end
      end

      it 'should correctly find existing load balancers' do
        VCR.use_cassette('elb-named-test') do
          @provider.exists?.should be true
        end
      end
    end

    context 'create' do
    end

    context 'destroy' do
    end

  end

end
