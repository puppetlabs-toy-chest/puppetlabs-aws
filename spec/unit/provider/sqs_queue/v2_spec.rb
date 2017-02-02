require 'spec_helper'
require_relative '../../../../lib/puppet_x/puppetlabs/aws.rb'

provider_class = Puppet::Type.type(:sqs_queue).provider(:v2)



describe provider_class do
  context 'with params' do
    let(:resource) do 
      Puppet::Type.type(:sqs_queue).new(
        name: 'queue',
        region: 'sa-east-1',
        delay_seconds: 10,
        message_retention_period: 699
      ) 
    end

    let(:provider) { resource.provider }

    let(:instance) { provider.class.instances.first }

    it 'should be an instance of the ProviderV2' do
      expect(provider).to be_an_instance_of Puppet::Type::Sqs_queue::ProviderV2
    end

    describe 'self.prefetch' do
      it 'exists' do
        VCR.use_cassette('sqs-setup') do
          provider.class.instances
          provider.class.prefetch({})
        end
      end
    end

    describe 'no given queue name' do
      it 'exists' do
        VCR.use_cassette('unnamed-queue') do
          expect(provider.exists?).to be_falsey
        end
      end
    end

    describe 'given queue name' do
      it 'exists' do
        VCR.use_cassette('named-queue') do
          expect(instance.exists?).to be_truthy
        end
      end
    end
  end

  context "creating and destroying" do
    let(:resource) do 
      Puppet::Type.type(:sqs_queue).new(
        name: 'queue2',
        region: 'sa-east-1',
        delay_seconds: 10,
      ) 
    end
    let(:provider) { resource.provider }
    let(:instance) { provider.class.instances.first }
    describe 'create and destroy queue' do
      queue_url = ''
      def get_queue_url (name)
        VCR.use_cassette('get_queue') do
          instance.queue_url_from_name(name)
        end
      end
      it 'creates' do
        VCR.use_cassette('create-named-queue') do
          expect(provider.create).to be_truthy
        end
      end

      it "gets the queue url" do
        queue_url = get_queue_url('queue')
      end
     let(:resource) do 
       Puppet::Type.type(:sqs_queue).new(
         name: 'queue',
         region: 'sa-east-1',
         url:  queue_url
       ) 
     end
      it "destroys the queue" do
        VCR.use_cassette('destroy-queue') do
          expect(provider.destroy).to be_nil
        end
      end
    end
  end
end
