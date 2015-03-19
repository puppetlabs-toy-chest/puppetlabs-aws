require 'spec_helper'
require_relative '../../lib/puppet_x/puppetlabs/aws_ingress_rules_parser.rb'

describe PuppetX::Puppetlabs::AwsIngressRulesParser do
  let(:subject) { PuppetX::Puppetlabs::AwsIngressRulesParser }

  describe '#rule_to_permission_list' do # (ec2, rule, group_id, group_name)
  end

  describe '#permissions_to_rules_list' do # (ec2, ipps, group_name)
  end

  describe '#rule2ipp' do # (ec2, rule, group_id, group_name)
  end

  describe '#ipp2rule' do # (ec2, ipp, group_name)
  end

  describe '#idname2id' do # (ec2, group_id_or_name, group_id, group_name)
    let(:ec2) { stub('ec2') }

    it 'returns group_id_or_name when it is in id form' do
      expect(subject.idname2id(nil, 'sg-123', nil, nil)).to eq('sg-123')
    end

    it 'returns group_id when group_id_or_name = group_name' do
      ec2.expects(:describe_security_groups).
        with(filters: [{name: 'group-name', values: ['foo']}]).
        returns(stub(data: stub(security_groups: [stub(group_id: 'sg-123')])))

      expect(subject.idname2id(ec2, 'foo', 'sg-123', 'bar')).to eq('sg-123')
    end

    it 'requests group data from ec2' do
      expect(subject.idname2id(nil, 'blah', 'sg-123', 'blah')).to eq('sg-123')
    end

    it 'fails when no groups found'
    it 'warns when more than 1 group found'
    it 'returns group name from ec2 data'
  end

  describe '#id2name' do # (ec2, group_id)
    it 'passes filter for group-id and returns correct name' do
      ec2 = stub('ec2')
      ec2.expects(:describe_security_groups).
        with(filters: [{name: 'group-id', values: ['123']}]).
        returns(stub(data: stub(security_groups: [stub(group_name: '123')])))

      expect(subject.id2name(ec2, '123')).to eq('123')
    end
  end
end
