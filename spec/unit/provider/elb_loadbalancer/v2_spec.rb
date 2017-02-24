require 'spec_helper'

provider_class = Puppet::Type.type(:elb_loadbalancer).provider(:v2)


describe provider_class do

  context 'with the minimum params' do
    let(:resource_hash) {
       {
        name: 'lb-1',
        instances: ['web-1'],
        listeners: [
          {
            'instance_port'      => '80',
            'instance_protocol'  => 'TCP',
            'load_balancer_port' => '80',
            'protocol'           => 'TCP'
          }
        ],
        availability_zones: ['sa-east-1a'],
        region: 'sa-east-1',
      }
    }

    let(:resource) {
      Puppet::Type.type(:elb_loadbalancer).new(resource_hash)
    }

    let(:provider) { resource.provider }
    let(:instance) { provider.class.instances.first }

    it 'should be an instance of the ProviderV2' do
      expect(provider).to be_an_instance_of Puppet::Type::Elb_loadbalancer::ProviderV2
    end

    describe 'self.prefetch' do
      it 'exists' do
        VCR.use_cassette('elb-setup') do
          provider.class.instances
          provider.class.prefetch({})
        end
      end
    end

    describe 'exists?' do
      it 'should correctly report non-existent load balancers' do
        VCR.use_cassette('no-elb-named-test') do
          provider.class.prefetch({"lb-2" => resource})
          expect(provider.exists?).to be_falsy
        end
      end

      it 'should correctly find existing load balancers' do
        VCR.use_cassette('elb-named-test') do
          data = provider.class.prefetch({"lb-1" => resource})
          expect(data[0].exists?).to be_truthy
        end
      end
    end

    describe 'create' do
      it 'should send a request to the ELB API to create the load balancer' do
        VCR.use_cassette('create-elb-test') do
          expect(provider.create).to be_truthy
        end
      end
    end

    describe 'destroy' do
      it 'should send a request to the ELB API to destroy the load balancer' do
        VCR.use_cassette('destroy-elb-test') do
          expect(provider.destroy).to be_truthy
        end
      end
    end

  end

  context 'listener handling' do
    let(:resource_hash) {
       {
        name: 'lb-1',
        instances: ['web-1'],
        listeners: [
          {
            'instance_port'      => '80',
            'instance_protocol'  => 'TCP',
            'load_balancer_port' => '80',
            'protocol'           => 'TCP'
          },
          {
            'instance_port'      => '443',
            'instance_protocol'  => 'HTTP',
            'load_balancer_port' => '443',
            'protocol'           => 'HTTPS',
            'ssl_certificate_id' => "arn:aws:iam::671116509167:server-certificate/zleslie-2016",
          }
        ],
        availability_zones: ['sa-east-1a'],
        region: 'sa-east-1',
      }
    }

    let(:resource) { Puppet::Type.type(:elb_loadbalancer).new(resource_hash) }
    let(:provider) { resource.provider }

    describe 'policy' do
      it 'should correctly detect existing policies' do
        VCR.use_cassette('elb_loadbalancer-policies', :allow_playback_repeats => true) do
          data = provider.class.prefetch({"lb-1" => resource})
          instance = data[0]
          instance.flush
          listeners = instance.listeners.dup
          expect(listeners[0]['protocol']).to eq('TCP')
          expect(listeners[0]['load_balancer_port']).to eq(80)

          expect(listeners[1]['policies'][0]['SSLNegotiationPolicyType']['Protocol-TLSv1.1']).to be(true)

        end
      end

    end
  end

  context 'merge_policies' do
    let(:resource_hash) {
       {
        name: 'lb-1',
        instances: ['web-1'],
        listeners: [
          {
            'instance_port'      => '80',
            'instance_protocol'  => 'TCP',
            'load_balancer_port' => '80',
            'protocol'           => 'TCP'
          }
        ],
        availability_zones: ['sa-east-1a'],
        region: 'sa-east-1',
      }
    }

    let(:resource) {
      Puppet::Type.type(:elb_loadbalancer).new(resource_hash)
    }

    let(:provider) { resource.provider }

    context 'when the is and should key values match' do
      let(:is_policies) {
        [
          {
            "SSLNegotiationPolicyType"=> {
              "Protocol-TLSv1.1" => false,
              "Protocol-TLSv1.2" => true,
              "ADH-AES128-GCM-SHA256"=>false,
              "ADH-AES128-SHA"=>false,
              "ADH-AES128-SHA256"=>false,
              "ADH-AES256-GCM-SHA384"=>false,
              "ADH-AES256-SHA"=>false,
              "ADH-AES256-SHA256"=>false,
              "ADH-CAMELLIA128-SHA"=>false,
              "ADH-CAMELLIA256-SHA"=>false,
              "ADH-DES-CBC-SHA"=>false,
            }
          }
        ]
      }

      let(:should_policies) {
        [
          {
            'SSLNegotiationPolicyType' => {
              'Protocol-TLSv1.1' => false,
              'Protocol-TLSv1.2' => true,
            }
          }
        ]
      }

      it 'should be equal' do
        merged_policies = provider.class.merge_policies(is_policies, should_policies)
        expect(merged_policies).to eq(is_policies)
      end

    end

    context 'when the is and should key values differ' do
      let(:is_policies) {
        [
          {
            "SSLNegotiationPolicyType"=> {
              "Protocol-TLSv1.1" => false,
              "Protocol-TLSv1.2" => true,
              "ADH-AES128-GCM-SHA256"=>false,
              "ADH-AES128-SHA"=>false,
              "ADH-AES128-SHA256"=>false,
              "ADH-AES256-GCM-SHA384"=>false,
              "ADH-AES256-SHA"=>false,
              "ADH-AES256-SHA256"=>false,
              "ADH-CAMELLIA128-SHA"=>false,
              "ADH-CAMELLIA256-SHA"=>false,
              "ADH-DES-CBC-SHA"=>false,
            }
          }
        ]
      }

      let(:should_policies) {
        [
          {
            'SSLNegotiationPolicyType' => {
              'Protocol-TLSv1.1' => true,
              'Protocol-TLSv1.2' => true,
            }
          }
        ]
      }

      it 'should be unequal' do
        merged_policies = provider.class.merge_policies(is_policies, should_policies)
        expect(merged_policies).to_not eq(is_policies)
      end
    end

    context 'when the is and should key values differ' do
      let(:is_policies) {
        [
          {
            "SSLNegotiationPolicyType"=> {
              "Protocol-TLSv1.1" => false,
              "Protocol-TLSv1.2" => true,
              "ADH-AES128-GCM-SHA256"=>false,
              "ADH-AES128-SHA"=>false,
              "ADH-AES128-SHA256"=>false,
              "ADH-AES256-GCM-SHA384"=>false,
              "ADH-AES256-SHA"=>false,
              "ADH-AES256-SHA256"=>false,
              "ADH-CAMELLIA128-SHA"=>false,
              "ADH-CAMELLIA256-SHA"=>false,
              "ADH-DES-CBC-SHA"=>false,
            }
          }
        ]
      }

      let(:should_policies) {
        [
          {
            'PublicKeyPolicyType' => {
              'PublicKey' => 'something goes here',
            }
          }
        ]
      }

      it 'should be unequal' do
        merged_policies = provider.class.merge_policies(is_policies, should_policies)
        expect(merged_policies).to_not eq(is_policies)
      end

    end

  end

end
