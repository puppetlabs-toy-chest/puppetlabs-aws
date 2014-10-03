require 'spec_helper'

provider_class = Puppet::Type.type(:ec2_securitygroup).provider(:v2)

ENV['AWS_ACCESS_KEY_ID'] = 'redacted'
ENV['AWS_SECRET_ACCESS_KEY'] = 'redacted'

describe provider_class do

  context 'with the minimum params' do
    before(:each) do
      @resource = Puppet::Type.type(:ec2_securitygroup).new(
        name: 'test',
        description: 'Security group for testing',
        region: 'us-west-2',
        ingress: [{
          protocol: 'tcp',
          port: 80,
          cidr: '0.0.0.0/0'
        }]
      )
      @provider = provider_class.new(@resource)
    end

    it 'should be an instance of the ProviderV2' do
      expect(@provider).to be_an_instance_of Puppet::Type::Ec2_securitygroup::ProviderV2
    end

    context 'exists?' do
      it 'should correctly report non-existent group' do
        VCR.use_cassette('no-group-named-test') do
          expect(@provider.exists?).to be false
        end
      end

      xit 'should correctly find existing groups' do
        VCR.use_cassette('group-named-test') do
          expect(@provider.exists?).to be true
        end
      end
    end

    context 'create' do
      it 'should send a request to the EC2 API to create the group' do
        VCR.use_cassette('create-test') do
          @provider.create
        end
      end
    end

    context 'destroy' do
      it 'should send a request to the EC2 API to destroy the group' do
        VCR.use_cassette('destroy-test') do
          @provider.destroy
        end
      end
    end

  end

end
