require 'spec_helper'

provider_class = Puppet::Type.type(:ecs_service).provider(:v2)


describe provider_class do

  before do
    ENV['AWS_ACCESS_KEY_ID'] = 'redacted'
    ENV['AWS_SECRET_ACCESS_KEY'] = 'redacted'
    ENV['AWS_REGION'] = 'us-west-2'
  end

  let(:resource) {
    Puppet::Type.type(:ecs_service).new(
      name: 'myshinyservice',
      cluster: 'mycluster',
    )
  }

  let(:provider) { resource.provider }
  VCR.use_cassette('ecs-service-setup') do
    let(:instance) { provider.class.instances.first }
  end

  it 'should be an instance of the ProviderV2' do
    expect(provider).to be_an_instance_of Puppet::Type::Ecs_service::ProviderV2
  end

  describe 'self.prefetch' do
    it 'should exist' do
      VCR.use_cassette('ecs-service-setup') do
        provider.class.instances
        provider.class.prefetch({})
        expect(instance.exists?).to be_truthy
      end
    end
  end

end


