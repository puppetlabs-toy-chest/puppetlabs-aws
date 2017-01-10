require 'spec_helper'

provider_class = Puppet::Type.type(:ec2_instance).provider(:v2)


describe provider_class do

  let(:resource) {
    Puppet::Type.type(:ec2_instance).new(
      name: 'web-15',
      image_id: 'ami-67a60d7a',
      instance_type: 't1.micro',
      tenancy: 'dedicated',
      availability_zone: 'sa-east-1a',
      region: 'sa-east-1',
      security_groups: ['web-sg'],
    )
  }

  let(:provider) { resource.provider }

  it 'should be an instance of the ProviderV2' do
    expect(provider).to be_an_instance_of Puppet::Type::Ec2_instance::ProviderV2
  end
end
