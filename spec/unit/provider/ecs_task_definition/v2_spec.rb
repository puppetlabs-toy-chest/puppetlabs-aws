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
        data = provider.class.prefetch({"testtask" => resource})
        prov = data.select {|m| m.name == 'testtask' }[0]
        expect(prov.destroy).to be_truthy
        expect(prov.exists?).to be_falsy
      end
    end
  end

  describe 'container_definitions' do
    it 'should retrieve the container_definition' do
      VCR.use_cassette('ecs_task_definition-setup') do
        data = provider.class.prefetch({"testtask" => resource})
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
        data = provider.class.prefetch({"testtask" => resource})
        prov = data.select {|m| m.name == 'testtask' }[0]

        container_defs = [
          {
            'cpu' => '1023',
          }
        ]

        prov.container_definitions=container_defs
        prov.flush
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

    it 'should sort array when processing array values' do

      hsh = {
        "Sid"=>"Allow access for Key Administrators",
        "Effect"=>"Allow",
        "Principal"=> {
          "AWS"=> [
            "arn:aws:iam::123456789012:user/u3",
            "arn:aws:iam::123456789012:user/u2",
            "arn:aws:iam::123456789012:user/u1",
            "arn:aws:iam::123456789012:user/u4"
          ]
        },
        "Action"=> [
          "kms:Describe*",
          "kms:Enable*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion",
          "kms:List*",
          "kms:Put*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:Create*"
        ],
        "Resource"=>"*"
      }

      wanted = {
        "Sid"=>"Allow access for Key Administrators",
        "Effect"=>"Allow",
        "Principal"=> {
          "AWS"=> [
            "arn:aws:iam::123456789012:user/u1",
            "arn:aws:iam::123456789012:user/u2",
            "arn:aws:iam::123456789012:user/u3",
            "arn:aws:iam::123456789012:user/u4"
          ]
        },
        "Action"=> [
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion"
        ],
        "Resource"=>"*"
      }

      normalized = provider.class.normalize_hash(hsh)
      expect(normalized).to eq(provider.class.normalize_hash(wanted))
    end

    it 'should fail when incorrect data type is passed' do
      expect do
        provider.class.normalize_hash([1,2,3])
      end.to raise_error(RuntimeError, /Invalid data type/)
    end

    it 'should handle a kms policy example' do

      hsh = {"Version"=>"2012-10-17", "Id"=>"key-consolepolicy-2",
             "Statement"=> [{"Sid"=>"Enable IAM User Permissions",
                             "Effect"=>"Allow",
                             "Principal"=>{"AWS"=>"arn:aws:iam::123456789012:root"},
                             "Action"=>"kms:*", "Resource"=>"*"},
                             {"Sid"=>"Allow access for Key Administrators",
                              "Effect"=>"Allow", "Principal"=> {"AWS"=>
                                                                ["arn:aws:iam::123456789012:user/t1",
                                                                 "arn:aws:iam::123456789012:user/t2",
                                                                 "arn:aws:iam::123456789012:user/t3",
                                                                 "arn:aws:iam::123456789012:user/t4"]},
                                                                 "Action"=>
                                                                ["kms:Create*",
                                                                 "kms:Describe*",
                                                                 "kms:Enable*",
                                                                 "kms:List*",
                                                                 "kms:Put*",
                                                                 "kms:Update*",
                                                                 "kms:Revoke*",
                                                                 "kms:Disable*",
                                                                 "kms:Get*",
                                                                 "kms:Delete*",
                                                                 "kms:ScheduleKeyDeletion",
                                                                 "kms:CancelKeyDeletion"],
                                                                 "Resource"=>"*"},
                                                                 {"Sid"=>"Allow
                                                                  use of the
                                                                key",
                                                                "Effect"=>"Allow",
                                                                "Principal"=>
                                                                {"AWS"=>
                                                                 ["arn:aws:iam::123456789012:user/t10",
                                                                  "arn:aws:iam::123456789012:user/t11",
                                                                  "arn:aws:iam::123456789012:user/t12",
                                                                  "arn:aws:iam::123456789012:user/t13"]},
                                                                  "Action"=>
                                                                 ["kms:Encrypt",
                                                                  "kms:Decrypt",
                                                                  "kms:ReEncrypt*",
                                                                  "kms:GenerateDataKey*",
                                                                  "kms:DescribeKey"],
                                                                  "Resource"=>"*"},
                                                                  {"Sid"=>"Allow
                                                                   attachment
                                                                 of persistent
                                                                 resources",
                                                                 "Effect"=>"Allow",
                                                                 "Principal"=>
                                                                 {"AWS"=>
                                                                  ["arn:aws:iam::123456789012:user/t10",
                                                                   "arn:aws:iam::123456789012:user/t11",
                                                                   "arn:aws:iam::123456789012:user/t12",
                                                                   "arn:aws:iam::123456789012:user/t13"]},
                                                                   "Action"=>["kms:CreateGrant",
                                                                              "kms:ListGrants",
                                                                              "kms:RevokeGrant"],
                                                                              "Resource"=>"*",
                                                                              "Condition"=>{"Bool"=>{"kms:GrantIsForAWSResource"=>"true"}}}]}

      wanted = {"Version"=>"2012-10-17", "Id"=>"key-consolepolicy-2",
             "Statement"=> [{"Sid"=>"Enable IAM User Permissions",
                             "Effect"=>"Allow",
                             "Principal"=>{"AWS"=>"arn:aws:iam::123456789012:root"},
                             "Action"=>"kms:*", "Resource"=>"*"},
                             {"Sid"=>"Allow access for Key Administrators",
                              "Effect"=>"Allow", "Principal"=> {"AWS"=>
                                                                ["arn:aws:iam::123456789012:user/t3",
                                                                 "arn:aws:iam::123456789012:user/t4",
                                                                 "arn:aws:iam::123456789012:user/t1",
                                                                 "arn:aws:iam::123456789012:user/t2"]},
                                                                 "Action"=>
                                                                ["kms:Create*",
                                                                 "kms:Get*",
                                                                 "kms:Describe*",
                                                                 "kms:Put*",
                                                                 "kms:Update*",
                                                                 "kms:Delete*",
                                                                 "kms:Revoke*",
                                                                 "kms:Disable*",
                                                                 "kms:Enable*",
                                                                 "kms:List*",
                                                                 "kms:ScheduleKeyDeletion",
                                                                 "kms:CancelKeyDeletion"],
                                                                 "Resource"=>"*"},
                                                                 {"Sid"=>"Allow
                                                                  use of the
                                                                key",
                                                                "Effect"=>"Allow",
                                                                "Principal"=>
                                                                {"AWS"=>
                                                                 ["arn:aws:iam::123456789012:user/t10",
                                                                  "arn:aws:iam::123456789012:user/t11",
                                                                  "arn:aws:iam::123456789012:user/t12",
                                                                  "arn:aws:iam::123456789012:user/t13"]},
                                                                  "Action"=>
                                                                 ["kms:Encrypt",
                                                                  "kms:Decrypt",
                                                                  "kms:ReEncrypt*",
                                                                  "kms:GenerateDataKey*",
                                                                  "kms:DescribeKey"],
                                                                  "Resource"=>"*"},
                                                                  {"Sid"=>"Allow
                                                                   attachment
                                                                 of persistent
                                                                 resources",
                                                                 "Effect"=>"Allow",
                                                                 "Principal"=>
                                                                 {"AWS"=>
                                                                  ["arn:aws:iam::123456789012:user/t10",
                                                                   "arn:aws:iam::123456789012:user/t11",
                                                                   "arn:aws:iam::123456789012:user/t12",
                                                                   "arn:aws:iam::123456789012:user/t13"]},
                                                                   "Action"=>["kms:CreateGrant",
                                                                              "kms:ListGrants",
                                                                              "kms:RevokeGrant"],
                                                                              "Resource"=>"*",
                                                                              "Condition"=>{"Bool"=>{"kms:GrantIsForAWSResource"=>"true"}}}]}



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

