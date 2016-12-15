require 'spec_helper'

provider_class = Puppet::Type.type(:ecs_task_definition).provider(:v2)


describe provider_class do

  before do
    ENV['AWS_ACCESS_KEY_ID'] = 'redacted'
    ENV['AWS_SECRET_ACCESS_KEY'] = 'redacted'
    ENV['AWS_REGION'] = 'us-west-2'
  end

  let(:resource) {
    Puppet::Type.type(:ecs_task_definition).new(
      name: 'omgolly123',
      container_definitions: []
    )
  }

  let(:provider) { resource.provider }
  VCR.use_cassette('ecs-setup') do
    let(:instance) { provider.class.instances.first }
  end

  it 'should be an instance of the ProviderV2' do
    expect(provider).to be_an_instance_of Puppet::Type::Ecs_task_definition::ProviderV2
  end

  describe 'self.prefetch' do
    it 'should exist' do
      VCR.use_cassette('ecs-setup') do
        provider.class.instances
        provider.class.prefetch({})
        expect(instance.exists?).to be_truthy
      end
    end
  end

  describe 'container_definitions' do
    it 'should retrieve the container_definition' do
      VCR.use_cassette('ecs-setup') do
        instance = provider.class.instances.first
        expect(instance.container_definitions.size).to eq(2)
        expect(instance.name).to eq('netflix-ice')
        container1 = instance.container_definitions[1]
        expect(container1['memory']).to eq(512)
        expect(container1['image']).to eq('debian:jessie')
        expect(container1['environment']['one']).to eq('1')
        expect(container1['environment']['two']).to eq('2')
      end
    end
  end

  describe 'container_definitions=' do
    it 'should set the container_definition' do
      VCR.use_cassette('ecs-setup') do
        instance = provider.class.instances.first

        container_defs = [
          {
            'cpu' => '1023',
          }
        ]

        instance.container_definitions=container_defs
        instance.flush
      end
    end
  end

  describe 'rectify_container_delta' do
    it 'should return zero results when containers match' do
      VCR.use_cassette('ecs-setup') do
        container_defs = [
          {
            'cpu'       => 1,
            'essential' => false,
            'image'     => 'debian:jessie',
            'memory'    => 256,
            'name'      => 'two'
          },{
            "cpu"         => 1021,
            "environment" => {
              "one" => 1,
              "two" => 2
          },
            "essential"     => true,
            "image"         => "debian:jessie",
            "memory"        => 512,
            "name"          => "zleslietesting",
            "port_mappings" => [
              {"container_port"=>8080, "host_port"=>8080, "protocol"=>"tcp"},
              {"container_port"=>8081, "host_port"=>8082, "protocol"=>"tcp"}
            ]
          }
        ]

        result = provider.rectify_container_delta(container_defs, {})
        expect(result.size).to eq(0)
      end
    end

    it 'should use discovered values in palce of missing values' do
      VCR.use_cassette('ecs-setup') do

        hsh = [
          {
            'cpu'       => 1,
            'essential' => false,
            #"image"         => "debian:jessie",
            'memory'    => 256,
            'name'      => 'two'
          },{
            "cpu"         => 1021,
            "environment" => {
              "one" => 1,
              "two" => 2
          },
            "essential"     => true,
            #"image"         => "debian:jessie",
            "memory"        => 512,
            "name"          => "zleslietesting",
            #"port_mappings" => [
            #  {"container_port"=>8080, "host_port"=>8080, "protocol"=>"tcp"},
            #  {"container_port"=>8081, "host_port"=>8082, "protocol"=>"tcp"}
            #]
          }
        ]

        wanted = [
          {
            'cpu'       => 1,
            'essential' => false,
            'image'     => 'debian:jessie',
            'memory'    => 256,
            'name'      => 'two'
          },{
            "cpu"         => 1021,
            "environment" => {
              "one" => 1,
              "two" => 2
          },
            "essential"     => true,
            "image"         => "debian:jessie",
            "memory"        => 512,
            "name"          => "zleslietesting",
            "port_mappings" => [
              {"container_port"=>8080, "host_port"=>8080, "protocol"=>"tcp"},
              {"container_port"=>8081, "host_port"=>8082, "protocol"=>"tcp"}
            ]
          }
        ]

        result = provider.rectify_container_delta(hsh, wanted)
        expect(result).to eq(wanted)
        expect(result[0]['image']).to eq('debian:jessie')
        expect(result[1]['image']).to eq('debian:jessie')
      end
    end

  end

  describe 'self.deserialize_environment' do
    it 'should handle deserialization correctly' do
      hsh = [
        {
          'name' => 'one',
          'value' => '1',
        },
        {
          'name' => 'two',
          'value' => '2',
        },
      ]

      wanted = {
        'one' => '1',
        'two' => '2',
      }
      expect(provider.class.deserialize_environment(hsh)).to eq(wanted)
    end
  end

  describe 'self.serialize_environment' do
    it 'should handle serialization correctly' do
      hsh = {
        'one' => '1',
        'two' => '2',
      }

      wanted = [
        {
          'name' => 'one',
          'value' => '1',
        },
        {
          'name' => 'two',
          'value' => '2',
        },
      ]
      expect(provider.class.serialize_environment(hsh)).to eq(wanted)
    end

    it 'should handle serialization correctly when integers are present' do
      hsh = {
        'one' => 1,
        'two' => 2,
      }

      wanted = [
        {
          'name' => 'one',
          'value' => '1',
        },
        {
          'name' => 'two',
          'value' => '2',
        },
      ]
      expect(provider.class.serialize_environment(hsh)).to eq(wanted)
    end
  end

  describe 'self.normalize_hash' do

    it 'should process a simple hash' do
      hsh = {
        'cpu'    => 1024,
        :memory => '128'
      }

      wanted = {
        'memory' => '128',
        'cpu'    => '1024'
      }

      expect(provider.class.normalize_hash(hsh)).to eq(provider.class.normalize_hash(wanted))
      expect(provider.class.normalize_hash(hsh)).to eq({"cpu"=>1024, "memory"=>128})
    end

    it 'should process a more complpicated hash' do
      hsh = {
        'environment' => [
          {
            'name'  => 'NONEMPTY',
            'value' => 'something goes here'
          },
          {
            'value' => '1',
            'name'  => 'one'
          },
          {
            'value' => '2',
            'name'  => 'two'
          },
        ],
        'essential'     => 'true',
        'port_mappings' => [
          {
            'protocol'       => 'tcp',
            'container_port' => '8081',
            'host_port'      => '8082',
          }, {
            'host_port'      => '8080',
            'container_port' => '8080',
            'protocol'       => 'tcp',
          }
        ],
        'name'   => 'zleslietesting',
        'memory' => '512',
        'image'  => 'debian:jessie',
        :cpu    => '1023',
      }

      wanted = {
        'cpu'         => '1023',
        'environment' => [
          {
            'name'  => 'two',
            'value' => '2'
          },
          {
            'name'  => 'one',
            'value' => 1
          },
          {
            'name'  => 'NONEMPTY',
            'value' => 'something goes here'
          },
        ],
        'image'         => 'debian:jessie',
        'memory'        => '512',
        'name'          => 'zleslietesting',
        'essential'     => true,
        'port_mappings' => [
          {
            'container_port' => '8081',
            'host_port'      => '8082',
            'protocol'       => 'tcp'
          }, {
            'container_port' => '8080',
            'host_port'      => '8080',
            'protocol'       => 'tcp'
          }
        ],
      }
      normalized = provider.class.normalize_hash(hsh)

      expect(normalized).to eq(provider.class.normalize_hash(wanted))
      expect(normalized['environment'].class).to be(Array)
      expect(normalized['essential'].class).to be(TrueClass)
      expect(normalized['cpu'].class).to be(Fixnum)
    end
  end

  describe "self.serialize_container_definitions" do

    it 'should correctly handle serializing a container definition' do
      container_list = [
        {
          'cpu'         => '1024',
          'environment' => {
            'item1'     => 'somevaluehere',
            'item2'     => 'somevaluehere',
            'item3'     => 'somevaluehere',
          },
          'essential'     => 'true',
          'image'         => 'quay.io/dockerdockerdocker',
          'memory'        => '4800',
          'name'          => 'some-service',
          'port_mappings' => [
            {
              'container_port' => 8080,
              'host_port'      => 8080,
              'protocol'       => 'tcp'
            },
            {
              'container_port' => 9080,
              'host_port'      => 9080,
              'protocol'       => 'tcp'
            }
          ]
        }
      ]

      serialized = provider.class.serialize_container_definitions(container_list)

      expect(serialized[0]['environment'].class).to eq(Array)
      expect(serialized[0]['environment'][0].class).to eq(Hash)
      expect(serialized[0]['environment'][1].class).to eq(Hash)
      expect(serialized[0]['environment'][2].class).to eq(Hash)
    end

  end

end

