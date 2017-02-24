require 'spec_helper'
require_relative '../../../../lib/puppet_x/puppetlabs/aws.rb'

describe 'PuppetX::Puppetlabs::Aws' do
  let(:aws) { PuppetX::Puppetlabs::Aws }

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

      expect(aws.normalize_hash(hsh)).to eq(aws.normalize_hash(wanted))
      expect(aws.normalize_hash(hsh)).to eq({"cpu"=>1024, "memory"=>128})
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
      normalized = aws.normalize_hash(hsh)

      expect(normalized).to eq(aws.normalize_hash(wanted))
      expect(normalized['environment'].class).to be(Array)
      expect(normalized['essential'].class).to be(TrueClass)
      expect(normalized['cpu'].class).to be(Fixnum)
    end

    it 'should handle nested hashes correct' do
      hsh = {
        'policy_attributes' => {
          'one' => true,
          'two' => false,
          'three' => false,
        },
        'policy_attributes2' => {
          'one' => 'true',
          'two' => false,
          'three' => 'false',
          'four' => {
            'eh' => 'bee',
            'cee' => 'true'
          }
        }
      }

      wanted = {
        'policy_attributes' => {
          'one' => true,
          'two' => false,
          'three' => false,
        },
        'policy_attributes2' => {
          'one' => 'true',
          'two' => false,
          'three' => 'false',
          'four' => {
            'eh' => 'bee',
            'cee' => true
          }
        }
      }

      normalized = aws.normalize_hash(hsh)
      wanted_normalized = aws.normalize_hash(wanted)

      expect(normalized).to eq(aws.normalize_hash(wanted))
      expect(normalized['policy_attributes']['one']).to be(true)
      expect(normalized['policy_attributes']['one']).to be(true)

      expect(normalized['policy_attributes2']['four']['cee']).to be(true)
      expect(wanted_normalized['policy_attributes2']['four']['cee']).to be(true)

    end
  end

  describe 'self.normalize_values' do

    ary = [
      {
        "protocol"=>"HTTPS",
        "load_balancer_port"=>443,
        "instance_protocol"=>"HTTP",
        "instance_port"=>80,
        "ssl_certificate_id"=>
        "arn:aws:iam::111111111111:server-certificate/zleslie-2016",
        "policy_attributes"=> {
          "Protocol-TLSv1"=>"false",
          "Protocol-SSLv3"=>"false",
          "Protocol-TLSv1.1"=>"true",
          "Protocol-TLSv1.2"=>"true",
          "Server-Defined-Cipher-Order"=>"true",
          "ECDHE-ECDSA-AES128-GCM-SHA256"=>"true",
          "ECDHE-RSA-AES128-GCM-SHA256"=>"true",
          "ECDHE-ECDSA-AES128-SHA256"=>"true",
          "ECDHE-RSA-AES128-SHA256"=>"true",
          "ECDHE-ECDSA-AES128-SHA"=>"true",
          "ECDHE-RSA-AES128-SHA"=>"true",
          "DHE-RSA-AES128-SHA"=>"false",
          "ECDHE-ECDSA-AES256-GCM-SHA384"=>"true",
          "ECDHE-RSA-AES256-GCM-SHA384"=>"true",
          "ECDHE-ECDSA-AES256-SHA384"=>"true",
          "ECDHE-RSA-AES256-SHA384"=>"true",
          "ECDHE-RSA-AES256-SHA"=>"true",
          "ECDHE-ECDSA-AES256-SHA"=>"true",
          "AES128-GCM-SHA256"=>"true",
          "AES128-SHA256"=>"true",
          "AES128-SHA"=>"true",
          "AES256-GCM-SHA384"=>"true",
          "AES256-SHA256"=>"true",
          "AES256-SHA"=>"true",
          "DHE-DSS-AES128-SHA"=>"false",
          "CAMELLIA128-SHA"=>"false",
          "EDH-RSA-DES-CBC3-SHA"=>"false",
          "DES-CBC3-SHA"=>"false",
          "ECDHE-RSA-RC4-SHA"=>"false",
          "RC4-SHA"=>"false",
          "ECDHE-ECDSA-RC4-SHA"=>"false",
          "DHE-DSS-AES256-GCM-SHA384"=>"false",
          "DHE-RSA-AES256-GCM-SHA384"=>"false",
          "DHE-RSA-AES256-SHA256"=>"false",
          "DHE-DSS-AES256-SHA256"=>"false",
          "DHE-RSA-AES256-SHA"=>"false",
          "DHE-DSS-AES256-SHA"=>"false",
          "DHE-RSA-CAMELLIA256-SHA"=>"false",
          "DHE-DSS-CAMELLIA256-SHA"=>"false",
          "CAMELLIA256-SHA"=>"false",
          "EDH-DSS-DES-CBC3-SHA"=>"false",
          "DHE-DSS-AES128-GCM-SHA256"=>"false",
          "DHE-RSA-AES128-GCM-SHA256"=>"false",
          "DHE-RSA-AES128-SHA256"=>"false",
          "DHE-DSS-AES128-SHA256"=>"false",
          "DHE-RSA-CAMELLIA128-SHA"=>"false",
          "DHE-DSS-CAMELLIA128-SHA"=>"false",
          "ADH-AES128-GCM-SHA256"=>"false",
          "ADH-AES128-SHA"=>"false",
          "ADH-AES128-SHA256"=>"false",
          "ADH-AES256-GCM-SHA384"=>"false",
          "ADH-AES256-SHA"=>"false",
          "ADH-AES256-SHA256"=>"false",
          "ADH-CAMELLIA128-SHA"=>"false",
          "ADH-CAMELLIA256-SHA"=>"false",
          "ADH-DES-CBC3-SHA"=>"false",
          "ADH-DES-CBC-SHA"=>"false",
          "ADH-RC4-MD5"=>"false",
          "ADH-SEED-SHA"=>"false",
          "DES-CBC-SHA"=>"false",
          "DHE-DSS-SEED-SHA"=>"false",
          "DHE-RSA-SEED-SHA"=>"false",
          "EDH-DSS-DES-CBC-SHA"=>"false",
          "EDH-RSA-DES-CBC-SHA"=>"false",
          "IDEA-CBC-SHA"=>"false",
          "RC4-MD5"=>"false",
          "SEED-SHA"=>"false",
          "DES-CBC3-MD5"=>"false",
          "DES-CBC-MD5"=>"false",
          "RC2-CBC-MD5"=>"false",
          "PSK-AES256-CBC-SHA"=>"false",
          "PSK-3DES-EDE-CBC-SHA"=>"false",
          "KRB5-DES-CBC3-SHA"=>"false",
          "KRB5-DES-CBC3-MD5"=>"false",
          "PSK-AES128-CBC-SHA"=>"false",
          "PSK-RC4-SHA"=>"false",
          "KRB5-RC4-SHA"=>"false",
          "KRB5-RC4-MD5"=>"false",
          "KRB5-DES-CBC-SHA"=>"false",
          "KRB5-DES-CBC-MD5"=>"false",
          "EXP-EDH-RSA-DES-CBC-SHA"=>"false",
          "EXP-EDH-DSS-DES-CBC-SHA"=>"false",
          "EXP-ADH-DES-CBC-SHA"=>"false",
          "EXP-DES-CBC-SHA"=>"false",
          "EXP-RC2-CBC-MD5"=>"false",
          "EXP-KRB5-RC2-CBC-SHA"=>"false",
          "EXP-KRB5-DES-CBC-SHA"=>"false",
          "EXP-KRB5-RC2-CBC-MD5"=>"false",
          "EXP-KRB5-DES-CBC-MD5"=>"false",
          "EXP-ADH-RC4-MD5"=>"false",
          "EXP-RC4-MD5"=>"false",
          "EXP-KRB5-RC4-SHA"=>"false",
          "EXP-KRB5-RC4-MD5"=>"false"
        }
      },
      {
        "protocol"=>"TCP",
        "load_balancer_port"=>80,
        "instance_protocol"=>"TCP",
        "instance_port"=>80
      }
    ]

    it 'should not mangle up the nested hash' do
      normalized = aws.normalize_values(ary)
      expect(normalized.class).to be(Array)

      expect(normalized.length).to eq(2)

      expect(normalized[0].class).to be(Hash)
      expect(normalized[0]['protocol']).to eq('HTTPS')
      expect(normalized[0]['load_balancer_port']).to eq(443)
      expect(normalized[0]['instance_port']).to eq(80)
      expect(normalized[0]['policy_attributes'].class).to be(Hash)
      expect(normalized[0]['policy_attributes']['Protocol-TLSv1']).to eq(false)

      expect(normalized[1].class).to be(Hash)
      expect(normalized[1]['protocol']).to eq('TCP')
      expect(normalized[1]['instance_port']).to eq(80)

    end
  end

end
