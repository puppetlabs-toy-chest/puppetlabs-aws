require 'spec_helper'

provider_class = Puppet::Type.type(:ec2_volume).provider(:v2)

describe provider_class do

  let(:resource) {
    Puppet::Type.type(:ec2_volume).new(
      name: 'test-volume',
      region: 'sa-east-1',
      size: '10',
      volume_type: 'gp2',
      iops: '300',
      availability_zone: 'sa-east-1a',
    )
  }

  let(:provider) { resource.provider }

  let(:instance) { provider.class.instances.first }

  it 'should be an instance of the ProviderV2' do
    expect(provider).to be_an_instance_of Puppet::Type::Ec2_volume::ProviderV2
  end
end
