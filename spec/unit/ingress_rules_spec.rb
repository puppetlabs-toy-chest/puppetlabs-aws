require 'spec_helper'
require 'puppet_x/puppetlabs/aws_ingress_rules_parser'

describe PuppetX::Puppetlabs::AwsIngressRulesParser do
  context 'starting with a blank rule set' do
    let(:parser) { PuppetX::Puppetlabs::AwsIngressRulesParser.new([]) }

    describe '#rules_to_create' do
      it 'should be empty if passed a blank rule set' do
        expect(parser.rules_to_create([])).to be_empty
      end
    end

    describe '#to_delete' do
      it 'should be empty if passed a blank rule set' do
        expect(parser.rules_to_delete([])).to be_empty
      end
    end
  end

  context 'starting with a single port' do
    let(:rules) { [{ 'port' => 80 }] }
    let(:parser) { PuppetX::Puppetlabs::AwsIngressRulesParser.new(rules) }

    context 'compared a blank rule set' do

      describe '#rules_to_create' do
        it 'should expand the protocols, and use to_ and from_ keys' do
          expect(parser.rules_to_create([])).to eq([
            {"from_port"=>"80", "to_port"=>"80", "protocol"=>"tcp"},
            {"from_port"=>"80", "to_port"=>"80", "protocol"=>"udp"},
            {"from_port"=>"-1", "to_port"=>"-1", "protocol"=>"icmp"}
          ])
        end
      end

      describe '#to_delete' do
        it 'should be empty' do
          expect(parser.rules_to_delete([])).to be_empty
        end
      end

    end
  end

  context 'starting with a single security group' do
    let(:rules) { [{ 'security_group' => 'sample-group' }] }
    let(:parser) { PuppetX::Puppetlabs::AwsIngressRulesParser.new(rules) }

    context 'compared to a blank rule set' do

      describe '#rules_to_create' do
        it 'should expand the protocols, and use to_ and from_ keys' do
          expect(parser.rules_to_create([])).to eq([
            {"security_group"=>"sample-group", "from_port"=>"1", "to_port"=>"65535", "protocol"=>"tcp"},
            {"security_group"=>"sample-group", "from_port"=>"1", "to_port"=>"65535", "protocol"=>"udp"},
            {"security_group"=>"sample-group", "from_port"=>"-1", "to_port"=>"-1", "protocol"=>"icmp"}
          ])
        end
      end

      describe '#to_delete' do
        it 'should be empty' do
          expect(parser.rules_to_delete([])).to be_empty
        end
      end

    end
  end

  context 'starting with a single cidr group' do
    let(:rules) { [{ 'cidr' => '0.0.0.0/0' }] }
    let(:parser) { PuppetX::Puppetlabs::AwsIngressRulesParser.new(rules) }

    context 'compared to a blank rule set' do

      describe '#rules_to_create' do
        it 'should expand the protocols, and use to_ and from_ keys' do
          expect(parser.rules_to_create([])).to eq([
            {"cidr"=>"0.0.0.0/0", "from_port"=>"1", "to_port"=>"65535", "protocol"=>"tcp"},
            {"cidr"=>"0.0.0.0/0", "from_port"=>"1", "to_port"=>"65535", "protocol"=>"udp"},
            {"cidr"=>"0.0.0.0/0", "from_port"=>"-1", "to_port"=>"-1", "protocol"=>"icmp"}
          ])
        end
      end

      describe '#to_delete' do
        it 'should be empty' do
          expect(parser.rules_to_delete([])).to be_empty
        end
      end

    end
  end

  context 'starting with a rule with a protocol' do
    let(:rules) { [{ 'security_group' => 'sample-group', 'protocol' => 'tcp' }] }
    let(:parser) { PuppetX::Puppetlabs::AwsIngressRulesParser.new(rules) }

    context 'compared to a blank rule set' do

      describe '#rules_to_create' do
        it 'should not expand the protocols, but should use to_ and from_ keys' do
          expect(parser.rules_to_create([])).to eq([
            {"security_group"=>"sample-group", "from_port"=>"1", "to_port"=>"65535", "protocol"=>"tcp"},
          ])
        end
      end

      describe '#to_delete' do
        it 'should be empty' do
          expect(parser.rules_to_delete([])).to be_empty
        end
      end

    end
  end

  context 'starting with a rule with port' do
    let(:rules) { [{ 'security_group' => 'sample-group', 'port' => 80 }] }
    let(:parser) { PuppetX::Puppetlabs::AwsIngressRulesParser.new(rules) }

    context 'compared to a blank rule set' do

      describe '#rules_to_create' do
        it 'should not expand the protocols, but should use to_ and from_ keys' do
          expect(parser.rules_to_create([])).to eq([
            {"security_group"=>"sample-group", "from_port"=>"80", "to_port"=>"80", "protocol"=>"tcp"},
            {"security_group"=>"sample-group", "from_port"=>"80", "to_port"=>"80", "protocol"=>"udp"},
            {"security_group"=>"sample-group", "from_port"=>"-1", "to_port"=>"-1", "protocol"=>"icmp"},
          ])
        end
      end

      describe '#to_delete' do
        it 'should be empty' do
          expect(parser.rules_to_delete([])).to be_empty
        end
      end

    end
  end

end
