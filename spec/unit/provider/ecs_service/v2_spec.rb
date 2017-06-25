require 'spec_helper'

provider_class = Puppet::Type.type(:ecs_service).provider(:v2)


describe provider_class do

  let(:resource) {
    Puppet::Type.type(:ecs_service).new(
      name: 'testservice',
      cluster: 'test',
      task_definition: 'testtask',
      desired_count: 0,
    )
  }

  let(:provider) { resource.provider }
  let(:instance) { provider.class.instances.first }

  before do
    # ECS is not supported in the spec_helper default region
    ENV['AWS_REGION'] = 'us-west-2'
  end

  it 'should be an instance of the ProviderV2' do
    expect(provider).to be_an_instance_of Puppet::Type::Ecs_service::ProviderV2
  end

  describe 'create' do
    it 'should make the call to create the service' do
      VCR.use_cassette('create-ecs_service') do
        expect(provider.create).to be_truthy
      end
    end
  end

  describe 'self.prefetch' do
    it 'should exist' do
      VCR.use_cassette('ecs_service-setup') do
        provider.class.instances
        provider.class.prefetch({})
        expect(instance.exists?).to be_truthy
      end
    end
  end

  describe 'destroy' do
    it 'should make the call to create the service' do
      VCR.use_cassette('destroy-ecs_service') do
        expect(provider.destroy).to be_truthy
      end
    end
  end

end

