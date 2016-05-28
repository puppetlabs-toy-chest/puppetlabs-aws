require 'spec_helper'

provider_class = Puppet::Type.type(:ec2_launchconfiguration).provider(:v2)

ENV['AWS_ACCESS_KEY_ID'] = 'redacted'
ENV['AWS_SECRET_ACCESS_KEY'] = 'redacted'
ENV['AWS_REGION'] = 'sa-east-1'

describe provider_class do

  let(:resource) {
    Puppet::Type.type(:ec2_launchconfiguration).new(
      name: 'test-lc',
      image_id: 'ami-67a60d7a',
      instance_type: 't1.micro',
      region: 'sa-east-1',
      security_groups: ['test-sg'],
    )
  }

  let(:resource_with_block_devices) {
    Puppet::Type.type(:ec2_launchconfiguration).new(
      name: 'test-lc',
      image_id: 'ami-67a60d7a',
      instance_type: 't1.micro',
      region: 'sa-east-1',
      security_groups: ['test-sg'],
      block_device_mappings: [
        { 'device_name' => '/dev/sda1', 'volume_size' => 8 },
        { 'device_name' => '/dev/sdb', 'volume_size' => 50 },
      ]
    )
  }

  let(:provider) { resource.provider }

  let(:instance) { provider.class.instances.first }

  it 'should be an instance of the ProviderV2' do
    expect(provider).to be_an_instance_of Puppet::Type::Ec2_launchconfiguration::ProviderV2
  end

  describe 'self.prefetch' do
    it 'should exist' do
      VCR.use_cassette('lc-setup') do
        provider.class.instances
        provider.class.prefetch({})
      end
    end
  end

  context 'with the minimum params' do

    describe 'running exists?' do
      it 'should correctly report non-existent instances' do
        VCR.use_cassette('no-lc-with-name') do
          expect(provider.exists?).to be_falsy
        end
      end

      it 'should correctly find existing launch configurations' do
        VCR.use_cassette('lc-with-name') do
          expect(instance.exists?).to be_truthy
        end
      end
    end

    describe 'running create' do
      it 'should send a request to the EC2 API to create the launch configuration' do
        VCR.use_cassette('create-lc') do
          expect(provider.create).to be_truthy
        end
      end
    end

    describe 'running destroy' do
      it 'should send a request to the EC2 API to destroy the launch configuration' do
        VCR.use_cassette('destroy-lc') do
          expect(provider.destroy).to be_truthy
        end
      end
    end

  end

end
