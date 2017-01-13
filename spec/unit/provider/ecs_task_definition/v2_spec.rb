require 'spec_helper'

provider_class = Puppet::Type.type(:ecs_task_definition).provider(:v2)


describe provider_class do

  let(:resource_hash) {
    {
      name: 'testtask',
      container_definitions: [
        {'cpu' => '1024', 'environment' => {'one' => 'one', 'two' => '2'}, 'essential' => 'true', 'image' => 'debian:jessie17', 'memory' => '512', 'name' => 'zleslietesting', 'port_mappings' => [{'container_port' => '8081', 'host_port' => '8082', 'protocol' => 'tcp'}]},
        {'cpu' => '1024', 'environment' => {'one' => 'one', 'two' => '2'}, 'essential' => 'true', 'image' => 'debian:jessie17', 'memory' => '512', 'name' => 'zleslietesting2', 'port_mappings' => [{'container_port' => '8082', 'host_port' => '8083', 'protocol' => 'tcp'}]},
      ]
    }
  }

  let(:resource) {
    Puppet::Type.type(:ecs_task_definition).new(resource_hash)
  }

  before do
    # ECS is not supported in the spec_helper default region
    ENV['AWS_REGION'] = 'us-west-2'
  end

  let(:provider) { resource.provider }
  let(:instance) {
    provider.class.instances.select {|i|
      i.name == 'testtask'
    }[0]
  }

  it 'should be an instance of the ProviderV2' do
    expect(provider).to be_an_instance_of Puppet::Type::Ecs_task_definition::ProviderV2
  end

  describe 'self.prefetch' do
    it 'exists' do
      VCR.use_cassette('ecs_task_definition-setup') do
        provider.class.instances
        provider.class.prefetch({})
      end
    end
  end

  describe 'exists?' do
    it 'should correctly report non-existent task definitions' do
      VCR.use_cassette('ecs_task_definition-setup') do
        expect(provider.exists?).to be_falsy
      end
    end
  end

  describe 'create' do
    it 'shold make the call to create the task definition' do
      VCR.use_cassette('create-ecs_task_definition') do
        expect(provider.create).to be_truthy
        expect(provider.exists?).to be_truthy
      end
    end
  end

  describe 'destroy' do
    it 'shold make the call to create the task definition' do
      VCR.use_cassette('destroy-ecs_task_definition') do
        data = provider.class.prefetch({"lb-1" => resource})
        prov = data.select {|m| m.name == 'testtask' }[0]
        expect(prov.destroy).to be_truthy
        expect(prov.exists?).to be_falsy
      end
    end
  end

  describe 'container_definitions' do
    it 'should retrieve the container_definition' do
      VCR.use_cassette('ecs_task_definition-setup') do
        data = provider.class.prefetch({"lb-1" => resource})
        prov = data.select {|m| m.name == 'testtask' }[0]
        expect(prov.name).to eq('testtask')
        container1 = prov.container_definitions[1]
        expect(container1['memory']).to eq(512)
        expect(container1['image']).to eq('debian:jessie17')
        expect(container1['environment']['one']).to eq('one')
        expect(container1['environment']['two']).to eq('2')
      end
    end
  end

  describe 'container_definitions=' do
    it 'should set the container_definition' do
      VCR.use_cassette('ecs_task_definition-setup') do
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
      VCR.use_cassette('ecs_task_definition-setup') do
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
      VCR.use_cassette('ecs_task_definition-setup') do

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

