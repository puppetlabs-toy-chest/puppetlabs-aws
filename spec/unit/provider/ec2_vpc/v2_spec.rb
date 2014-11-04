require 'spec_helper'

provider_class = Puppet::Type.type(:ec2_vpc).provider(:v2)

ENV['AWS_ACCESS_KEY_ID'] = 'redacted'
ENV['AWS_SECRET_ACCESS_KEY'] = 'redacted'
ENV['AWS_REGION'] = 'sa-east-1'

describe provider_class do

  let(:resource) {
    Puppet::Type.type(:ec2_vpc).new(
      name: 'test-vpc',
      cidr_block: '10.0.0.0/16',
      region: 'sa-east-1',
    )
  }

  let(:provider) { resource.provider }


  it 'should be an instance of the ProviderV2' do
    expect(provider).to be_an_instance_of Puppet::Type::Ec2_vpc::ProviderV2
  end

  describe 'self.prefetch' do
    it 'should exist' do
      VCR.use_cassette('vpc-setup') do
        provider.class.instances
        provider.class.prefetch({})
      end
    end
  end

  context 'with the minimum params' do

    describe 'running exists?' do
      it 'should correctly report non-existent VPC' do
        VCR.use_cassette('no-vpc-named-test') do
          expect(provider.exists?).to be_falsy
        end
      end

      it 'should correctly find existing VPCs' do
        VCR.use_cassette('vpc-named-test') do
          instance = provider.class.instances.first
          expect(instance.exists?).to be_truthy
        end
      end
    end

    describe 'running create' do
      it 'should send a request to the EC2 API to create the VPC' do
        VCR.use_cassette('create-vpc') do
          expect(provider.create).to be_truthy
        end
      end
    end

    describe 'running destroy' do
      it 'should send a request to the EC2 API to destroy the VPC' do
        VCR.use_cassette('destroy-vpc') do
          expect(provider.destroy).to be_truthy
        end
      end
    end

  end

end
