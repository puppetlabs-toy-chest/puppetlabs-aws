require 'spec_helper'

provider_class = Puppet::Type.type(:ec2_securitygroup).provider(:v2)


describe provider_class do

  context 'with the minimum params' do
    let(:resource) {
      Puppet::Type.type(:ec2_securitygroup).new(
        name: 'test-web-sg',
        description: 'Security group for testing',
        region: 'sa-east-1',
      )
    }

    let(:provider) { resource.provider }

    let(:instance) { provider.class.instances.first }

    it 'should be an instance of the ProviderV2' do
      expect(provider).to be_an_instance_of Puppet::Type::Ec2_securitygroup::ProviderV2
    end

    describe 'self.prefetch' do
      it 'exists' do
        VCR.use_cassette('group-setup') do
          provider.class.instances
          provider.class.prefetch({})
        end
      end
    end

    describe 'exists?' do
      it 'should correctly report non-existent group' do
        VCR.use_cassette('no-group-named-test') do
          expect(provider.exists?).to be_falsy
        end
      end

      it 'should correctly find existing groups' do
        VCR.use_cassette('group-named-test') do
          expect(instance.exists?).to be_truthy
        end
      end
    end

    describe 'create' do
      it 'should send a request to the EC2 API to create the group' do
        VCR.use_cassette('create-group') do
          expect(provider.create).to be_truthy
        end
      end
    end

    describe 'destroy' do
      it 'should send a request to the EC2 API to destroy the group' do
        VCR.use_cassette('destroy-group') do
          expect(provider.destroy).to be_truthy
        end
      end
    end

  end

end
