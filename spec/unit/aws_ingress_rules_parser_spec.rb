require 'spec_helper'
require_relative '../../lib/puppet_x/puppetlabs/aws_ingress_rules_parser.rb'

describe PuppetX::Puppetlabs::AwsIngressRulesParser do
  let(:subject) { PuppetX::Puppetlabs::AwsIngressRulesParser }
  let(:ec2) { stub('ec2') }
  let(:self_ref) { ['self_id', 'self'] }

  RULES = {
    sg_self:                { },
    sg_test:                { 'security_group' => 'test' },
    sg_self_sg_test:        { 'security_group' => %w{test self} },
    sg_self_tcp:            { 'protocol' => 'tcp' },
    sg_self_tcp_port:       { 'port' => 10, 'protocol' => 'tcp' },
    sg_self_tcp_port_range: { 'port' => [10, 100], 'protocol' => 'tcp' },
    sg_self_port:           { 'port' => 10 },
    sg_self_port_range:     { 'port' => [10, 100] },
    cidr:                   { 'cidr' => '0.0.0.0/8' },
    cidr_cidr:              { 'cidr' => ['0.0.0.0/8', '1.1.1.1/8'] },
    cidr_tcp:               { 'protocol' => 'tcp', 'cidr' => '0.0.0.0/8' },
    cidr_tcp_port:          { 'port' => 10, 'protocol' => 'tcp', 'cidr' => '0.0.0.0/8' },
    cidr_tcp_port_range:    { 'port' => [10, 100], 'protocol' => 'tcp', 'cidr' => '0.0.0.0/8' },
    cidr_port:              { 'port' => 10, 'cidr' => '0.0.0.0/8' },
    cidr_port_range:        { 'port' => [10, 100], 'cidr' => '0.0.0.0/8' } }

  VPC_IP_PERMISSION_LISTS = {
    sg_self:                [ { ip_protocol: -1,
                                user_id_group_pairs: [ { group_id: 'self_id' } ] } ],

    sg_test:                [ { ip_protocol: -1,
                                user_id_group_pairs: [ { group_id: 'test_id' } ] } ],

    sg_self_sg_test:        [ { ip_protocol: -1,
                                user_id_group_pairs: [ { group_id: 'test_id' },
                                                       { group_id: 'self_id'} ] } ],

    sg_self_tcp:            [ { ip_protocol: 'tcp',
                                user_id_group_pairs: [ { group_id: 'self_id' } ] } ],

    sg_self_tcp_port:       [ { ip_protocol: 'tcp', from_port: 10, to_port: 10,
                                user_id_group_pairs: [ { group_id: 'self_id' } ] } ],

    sg_self_tcp_port_range: [ { ip_protocol: 'tcp', from_port: 10, to_port: 100,
                                user_id_group_pairs: [ { group_id: 'self_id' } ] } ],

    sg_self_port:           [ { ip_protocol: -1, from_port: 10, to_port: 10,
                                user_id_group_pairs: [ { group_id: 'self_id' } ] } ],

    sg_self_port_range:     [ { ip_protocol: -1, from_port: 10, to_port: 100,
                                user_id_group_pairs: [ { group_id: 'self_id' } ] } ],

    cidr:                   [ { ip_protocol: -1,
                                ip_ranges: [ { cidr_ip: '0.0.0.0/8' } ] } ],

    cidr_cidr:              [ { ip_protocol: -1,
                                ip_ranges: [ { cidr_ip: '0.0.0.0/8' },
                                             { cidr_ip: '1.1.1.1/8' } ] } ],

    cidr_tcp:               [ { ip_protocol: 'tcp',
                                ip_ranges: [ { cidr_ip: '0.0.0.0/8' } ] } ],

    cidr_tcp_port:          [ { ip_protocol: 'tcp', from_port: 10, to_port: 10,
                                ip_ranges: [ { cidr_ip: '0.0.0.0/8' } ] } ],

    cidr_tcp_port_range:    [ { ip_protocol: 'tcp', from_port: 10, to_port: 100,
                                ip_ranges: [ { cidr_ip: '0.0.0.0/8' } ] } ],

    cidr_port:              [ { ip_protocol: -1, from_port: 10, to_port: 10,
                                ip_ranges: [ { cidr_ip: '0.0.0.0/8' } ] } ],

    cidr_port_range:        [ { ip_protocol: -1, from_port: 10, to_port: 100,
                                ip_ranges: [ { cidr_ip: '0.0.0.0/8' } ] } ] }

  NON_VPC_IP_PERMISSION_LISTS = {
    sg_self:                [ { ip_protocol: 'tcp',
                                user_id_group_pairs: [ { group_id: 'self_id' } ] },
                              { ip_protocol: 'udp',
                                user_id_group_pairs: [ { group_id: 'self_id' } ] },
                              { ip_protocol: 'icmp',
                                user_id_group_pairs: [ { group_id: 'self_id' } ] } ],

    sg_test:                [ { ip_protocol: 'tcp',
                                user_id_group_pairs: [ { group_id: 'test_id' } ] },
                              { ip_protocol: 'udp',
                                user_id_group_pairs: [ { group_id: 'test_id' } ] },
                              { ip_protocol: 'icmp',
                                user_id_group_pairs: [ { group_id: 'test_id' } ] } ],

    sg_self_sg_test:        [ { ip_protocol: 'tcp',
                                user_id_group_pairs: [ { group_id: 'test_id' },
                                                       { group_id: 'self_id' } ] },
                              { ip_protocol: 'udp',
                                user_id_group_pairs: [ { group_id: 'test_id' },
                                                       { group_id: 'self_id' } ] },
                              { ip_protocol: 'icmp',
                                user_id_group_pairs: [ { group_id: 'test_id' },
                                                       { group_id: 'self_id' } ] } ],

    sg_self_tcp:            [ { ip_protocol: 'tcp',
                                user_id_group_pairs: [ { group_id: 'self_id' } ] } ],

    sg_self_tcp_port:       [ { ip_protocol: 'tcp', from_port: 10, to_port: 10,
                                user_id_group_pairs: [ { group_id: 'self_id' } ] } ],

    sg_self_tcp_port_range: [ { ip_protocol: 'tcp', from_port: 10, to_port: 100,
                                user_id_group_pairs: [ { group_id: 'self_id' } ] } ],

    sg_self_port:           [ { ip_protocol: 'tcp', from_port: 10, to_port: 10,
                                user_id_group_pairs: [ { group_id: 'self_id' } ] },
                              { ip_protocol: 'udp', from_port: 10, to_port: 10,
                                user_id_group_pairs: [ { group_id: 'self_id' } ] },
                              { ip_protocol: 'icmp',
                                user_id_group_pairs: [ { group_id: 'self_id' } ] } ],

    sg_self_port_range:     [ { ip_protocol: 'tcp', from_port: 10, to_port: 100,
                                user_id_group_pairs: [ { group_id: 'self_id' } ] },
                              { ip_protocol: 'udp', from_port: 10, to_port: 100,
                                user_id_group_pairs: [ { group_id: 'self_id' } ] },
                              { ip_protocol: 'icmp',
                                user_id_group_pairs: [ { group_id: 'self_id' } ] } ],

    cidr:                   [ { ip_protocol: 'tcp',
                                ip_ranges: [ { cidr_ip: '0.0.0.0/8' } ] },
                              { ip_protocol: 'udp',
                                ip_ranges: [ { cidr_ip: '0.0.0.0/8' } ] },
                              { ip_protocol: 'icmp',
                                ip_ranges: [ { cidr_ip: '0.0.0.0/8' } ] } ],

    cidr_cidr:              [ { ip_protocol: 'tcp',
                                ip_ranges: [ { cidr_ip: '0.0.0.0/8' },
                                             { cidr_ip: '1.1.1.1/8' } ] },
                              { ip_protocol: 'udp',
                                ip_ranges: [ { cidr_ip: '0.0.0.0/8' },
                                             { cidr_ip: '1.1.1.1/8' } ] },
                              { ip_protocol: 'icmp',
                                ip_ranges: [ { cidr_ip: '0.0.0.0/8' },
                                             { cidr_ip: '1.1.1.1/8' } ] } ],

    cidr_tcp:               [ { ip_protocol: 'tcp',
                                ip_ranges: [ { cidr_ip: '0.0.0.0/8' } ] } ],

    cidr_tcp_port:          [ { ip_protocol: 'tcp', from_port: 10, to_port: 10,
                                ip_ranges: [ { cidr_ip: '0.0.0.0/8' } ] } ],

    cidr_tcp_port_range:    [ { ip_protocol: 'tcp', from_port: 10, to_port: 100,
                                ip_ranges: [ { cidr_ip: '0.0.0.0/8' } ] } ],

    cidr_port:              [ { ip_protocol: 'tcp', from_port: 10, to_port: 10,
                                ip_ranges: [ { cidr_ip: '0.0.0.0/8' } ] },
                              { ip_protocol: 'udp', from_port: 10, to_port: 10,
                                ip_ranges: [ { cidr_ip: '0.0.0.0/8' } ] },
                              { ip_protocol: 'icmp',
                                ip_ranges: [ { cidr_ip: '0.0.0.0/8' } ] } ],

    cidr_port_range:        [ { ip_protocol: 'tcp', from_port: 10, to_port: 100,
                                ip_ranges: [ { cidr_ip: '0.0.0.0/8' } ] },
                              { ip_protocol: 'udp', from_port: 10, to_port: 100,
                                ip_ranges: [ { cidr_ip: '0.0.0.0/8' } ] },
                              { ip_protocol: 'icmp',
                                ip_ranges: [ { cidr_ip: '0.0.0.0/8' } ] } ] }

  describe '#rule_to_ip_permission_list' do # (ec2, rule, group_id, group_name)
    RULES.each do |key, rule|
      it "#{key} in non-vpc should expand" do
        ec2.stubs(:vpc_only_account? => false)

        # this should only stub calls for test_id group
        ec2.stubs(:describe_security_groups).returns(
          stub(data: stub(security_groups: [stub(group_id: 'test_id')])))

        expect(subject.rule_to_ip_permission_list(ec2, rule, self_ref)).to(
          eq(NON_VPC_IP_PERMISSION_LISTS[key]))
      end
    end

    RULES.each do |key, rule|
      it "#{key} in vpc should not expand" do
        ec2.stubs(:vpc_only_account? => true)

        # this should only stub calls for test_id group
        ec2.stubs(:describe_security_groups).returns(
          stub(data: stub(security_groups: [stub(group_id: 'test_id')])))

        expect(subject.rule_to_ip_permission_list(ec2, rule, self_ref)).to(
          eq(VPC_IP_PERMISSION_LISTS[key]))
      end
    end
  end

  describe '#ip_permissions_to_rules_list' do # (ec2, ipps, group_name)
    VPC_IP_PERMISSION_LISTS.each do |key, rule|
      it "#{key} in vpc should collapse" do
        ec2.stubs(:vpc_only_account? => true)

        # this should only stub calls for test_id group
        ec2.stubs(:describe_security_groups).returns(
          stub(data: stub(security_groups: [stub(group_name: 'test')])))

        expect(subject.ip_permissions_to_rules_list(ec2, rule, self_ref)).to(
          eq([RULES[key]]))
      end
    end

    NON_VPC_IP_PERMISSION_LISTS.each do |key, rule|
      it "#{key} in non-vpc should not collapse" do
        ec2.stubs(:vpc_only_account? => false)

        # this should only stub calls for test_id group
        ec2.stubs(:describe_security_groups).returns(
          stub(data: stub(security_groups: [stub(group_name: 'test')])))

        expect(subject.ip_permissions_to_rules_list(ec2, rule, self_ref)).to(
          eq([RULES[key]]))
      end
    end
  end

  describe '#rule_to_ip_permission' do # (ec2, rule, group_id, group_name)
    RULES.each do |key, rule|
      it key do
        ec2.stubs(:vpc_only_account? => true)

        # this should only stub calls for test_id group
        ec2.stubs(:describe_security_groups).returns(
          stub(data: stub(security_groups: [stub(group_id: 'test_id')])))

        expect(subject.rule_to_ip_permission(ec2, rule, self_ref)).to(
          eq(VPC_IP_PERMISSION_LISTS[key].first))
      end
    end
  end

  describe '#ip_permission_to_rule' do # (ec2, ipp, group_name)
    VPC_IP_PERMISSION_LISTS.each do |key, ipp|
      it key do
        ec2.stubs(:vpc_only_account? => true)

        # this should only stub calls for test_id group
        ec2.stubs(:describe_security_groups).returns(
          stub(data: stub(security_groups: [stub(group_name: 'test')])))

        expect(subject.ip_permission_to_rule(ec2, ipp.first, self_ref)).to(
          eq(RULES[key]))
      end
    end
  end

  describe '#name_to_id' do # (ec2, group_id_or_name, group_id, group_name)
    it 'returns group_id_or_name when it is in id form' do
      expect(subject.name_to_id(nil, 'sg-123')).to eq('sg-123')
    end

    it 'returns group_id when group_id_or_name = group_name' do
      expect(subject.name_to_id(nil, 'foo', ['sg-123', 'foo'])).to eq('sg-123')
    end

    it 'requests group data from ec2' do
      ec2.expects(:describe_security_groups).
        with(filters: [{name: 'group-name', values: ['foo']}]).
        returns(stub(data: stub(security_groups: [stub(group_id: 'sg-456')])))

      expect(subject.name_to_id(ec2, 'foo', ['sg-123', 'bar'])).to eq('sg-456')
    end

    it 'fails when no groups found' do
      ec2.expects(:describe_security_groups).
        with(filters: [{name: 'group-name', values: ['foo']}]).
        returns(stub(data: stub(security_groups: [])))

      expect { subject.name_to_id(ec2, 'foo') }.to raise_exception
    end

    it 'warns when more than 1 group found but returns first found' do
      ec2.expects(:describe_security_groups).
        with(filters: [{name: 'group-name', values: ['foo']}]).
        returns(stub(data: stub(security_groups: [
          stub(group_id: 'sg-123'),
          stub(group_id: 'sg-456')])))

      Puppet.expects(:warning)
      expect(subject.name_to_id(ec2, 'foo')).to eq('sg-123')
    end
  end

  describe '#id_to_name' do # (ec2, group_id)
    it 'returns data from cache' do
      expect(subject.id_to_name(ec2, 'id', ['id', 'name'])).to eq('name')
    end

    it 'passes filter for group-id and returns name from data' do
      ec2.expects(:describe_security_groups).
        with(filters: [{name: 'group-id', values: ['id']}]).
        returns(stub(data: stub(security_groups: [stub(group_name: 'name')])))

      expect(subject.id_to_name(ec2, 'id')).to eq('name')
    end
  end
end
