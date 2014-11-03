require 'spec_helper_acceptance'
require 'securerandom'

describe "ec2_securitygroup" do

  before(:all) do
    @default_region = 'sa-east-1'
    @ec2 = Ec2Helper.new(@default_region)
    @template = 'securitygroup.pp.tmpl'
  end

  def find_group(name)
    groups = @ec2.get_groups(name)
    expect(groups.count).to eq(1)
    groups.first
  end

  def has_matching_tags(group, tags)
    group_tags = {}
    group.tags.each { |s| group_tags[s.key.to_sym] = s.value if s.key != 'Name' }

    symmetric_difference = tags.to_set ^ group_tags.to_set
    expect(symmetric_difference).to be_empty
  end

  def get_group_permission(ip_permissions, group, protocol)
    ip_permissions.detect do |perm|
      pairs = perm[:user_id_group_pairs]
      pairs.any? do |pair|
        pair.group_name == group && perm[:ip_protocol] == protocol
      end
    end
  end

  # a fairly naive matching algorithm, since the shape of ip_permissions is
  # quite different than the shape of our ingress rules
  def has_ingress_rule(rule, ip_permissions)
    if (rule.has_key? :security_group)
      group_name = rule[:security_group]
      # a match occurs when AWS has a TCP / UDP / ICMP perm setup for group
      tcp_perm = get_group_permission(ip_permissions, group_name, 'tcp')
      udp_perm = get_group_permission(ip_permissions, group_name, 'udp')
      icmp_perm = get_group_permission(ip_permissions, group_name, 'icmp')
      match = !tcp_perm.nil? && !udp_perm.nil? && !icmp_perm.nil?
      expect(match).to eq(true), "Could not find ingress rule for #{group_name}"
    else
      match = ip_permissions.any? do |perm|
        rule[:protocol] == perm[:ip_protocol] &&
        rule[:port] == perm[:from_port] &&
        rule[:port] == perm[:to_port] &&
        perm[:ip_ranges].any? { |ip| ip[:cidr_ip] == rule[:cidr] }
      end
      msg = "Could not find ingress rule for #{rule[:protocol]} port #{rule[:port]} and CIDR #{rule[:cidr]}"
      expect(match).to eq(true), msg
    end
  end

  describe 'should create a new security group' do

    before(:all) do
      @name = "#{PuppetManifest.env_id}-#{SecureRandom.uuid}"
      @config = {
        :name => @name,
        :ensure => 'present',
        :description => 'aws acceptance securitygroup',
        :region => @default_region,
        :ingress => [
          {
            :security_group => @name,
          },{
            :protocol => 'tcp',
            :port     => 22,
            :cidr     => '0.0.0.0/0'
          }
        ],
        :tags => {
          :department => 'engineering',
          :project    => 'cloud',
          :created_by => 'aws-acceptance'
        }
      }

      PuppetManifest.new(@template, @config).apply
      @group = find_group(@config[:name])
    end

    after(:all) do
      new_config = @config.update({:ensure => 'absent'})
      PuppetManifest.new(@template, new_config).apply

      expect(find_group(@config[:name])).to be_nil
    end

    it "with the specified name" do
      expect(@group.group_name).to eq(@config[:name])
    end

    it "with the specified tags" do
      has_matching_tags(@group, @config[:tags])
    end

    it "with the specified description" do
      expect(@group.description).to eq(@config[:description])
    end

    it "with the specified ingress rules" do
      # perform a naive match
      @config[:ingress].all? { |rule| has_ingress_rule(rule, @group.ip_permissions)}
    end

  end

  describe 'should create a new securitygroup' do

    before(:each) do
      @name = "#{PuppetManifest.env_id}-#{SecureRandom.uuid}"
      @config = {
        :name => @name,
        :ensure => 'present',
        :description => 'aws acceptance sg',
        :region => @default_region,
        :ingress => [
          {
            :security_group => @name,
          },{
            :protocol => 'tcp',
            :port     => 22,
            :cidr     => '0.0.0.0/0'
          }
        ],
        :tags => {
          :department => 'engineering',
          :project    => 'cloud',
          :created_by => 'aws-acceptance'
        }
      }

      PuppetManifest.new(@template, @config).apply
      @group = find_group(@config[:name])
    end

    after(:each) do
      @config[:ensure] = 'absent'
      PuppetManifest.new(@template, @config).apply
    end

    it 'that can have tags changed' do
      pending 'changing tags not yet supported for security groups'
      has_matching_tags(@group, @config[:tags])

      tags = {:created_by => 'aws-tests', :foo => 'bar'}
      @config[:tags].update(tags)

      PuppetManifest.new(@template, @config).apply
      @group = find_group(@config[:name])
      has_matching_tags(@group, @config[:tags])
    end
  end

end
