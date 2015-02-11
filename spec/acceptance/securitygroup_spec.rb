require 'spec_helper_acceptance'
require 'securerandom'

describe "ec2_securitygroup" do

  before(:all) do
    @default_region = 'sa-east-1'
    @aws = AwsHelper.new(@default_region)
    @template = 'securitygroup.pp.tmpl'
  end

  def get_group(name)
    groups = @aws.get_groups(name)
    expect(groups.count).to eq(1)
    groups.first
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
  def check_ingress_rule(rule, ip_permissions)
    if (rule.has_key? :security_group)
      group_name = rule[:security_group]
      # a match occurs when AWS has a TCP / UDP / ICMP perm setup for group
      tcp_perm = get_group_permission(ip_permissions, group_name, 'tcp')
      udp_perm = get_group_permission(ip_permissions, group_name, 'udp')
      icmp_perm = get_group_permission(ip_permissions, group_name, 'icmp')
      match = !tcp_perm.nil? && !udp_perm.nil? && !icmp_perm.nil?
      msg = "Could not find ingress rule for #{group_name}"
    else
      match = ip_permissions.any? do |perm|
        rule[:protocol] == perm[:ip_protocol] &&
        rule[:port] == perm[:from_port] &&
        rule[:port] == perm[:to_port] &&
        perm[:ip_ranges].any? { |ip| ip[:cidr_ip] == rule[:cidr] }
      end
      msg = "Could not find ingress rule for #{rule[:protocol]} port #{rule[:port]} and CIDR #{rule[:cidr]}"
    end
    [match, msg]
  end

  def has_ingress_rule(rule, ip_permissions)
    match, msg = check_ingress_rule(rule, ip_permissions)
    expect(match).to eq(true), msg
  end

  def doesnt_have_ingress_rule(rule, ip_permissions)
    match, msg = check_ingress_rule(rule, ip_permissions)
    expect(match).to eq(false), msg
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
      @group = get_group(@config[:name])
    end

    after(:all) do
      new_config = @config.update({:ensure => 'absent'})
      PuppetManifest.new(@template, new_config).apply

      expect { get_group(@config[:name]) }.to raise_error(::Aws::EC2::Errors::InvalidGroupNotFound)
    end

    it "with the specified name" do
      expect(@group.group_name).to eq(@config[:name])
    end

    it "isn't attached to a VPC" do
      skip('VPC only accounts will fail here')
      expect(@group.vpc_id).to eq(nil)
    end

    it "with the specified tags" do
      expect(@aws.tag_difference(@group, @config[:tags])).to be_empty
    end

    it "with the specified description" do
      expect(@group.description).to eq(@config[:description])
    end

    it "with the specified ingress rules" do
      # perform a naive match
      @config[:ingress].all? { |rule| has_ingress_rule(rule, @group.ip_permissions)}
    end

    it 'should be able to modify the ingress rules and recreate the security group' do
      new_rules = [{
        :protocol => 'tcp',
        :port     => 80,
        :cidr     => '0.0.0.0/0'
      }]
      new_config = @config.dup.update({:ingress => new_rules})
      success = PuppetManifest.new(@template, new_config).apply[:exit_status].success?
      expect(success).to eq(false)

      # should still have the original rules
      @group = get_group(@config[:name])

      new_rules.all? { |rule| has_ingress_rule(rule, @group.ip_permissions)}
      @config[:ingress].all? { |rule| doesnt_have_ingress_rule(rule, @group.ip_permissions)}
    end

    describe 'that another group depends on in a secondary manifest' do
      before(:each) do
        @name_2 = "#{PuppetManifest.env_id}-#{SecureRandom.uuid}"
        new_config = {
          :name => @name_2,
          # need both sgs by name to trigger a potential issue here
          :ingress => [
            {
              :security_group => @name
            },{
              :security_group => @name_2
            }
          ],
        }
        @config_2 = @config.dup.update(new_config)

        PuppetManifest.new(@template, @config_2).apply
        @group_2 = get_group(@config_2[:name])
      end

      after(:each) do
        new_config = @config_2.update({:ensure => 'absent'})
        PuppetManifest.new(@template, new_config).apply

        expect { get_group(@config_2[:name]) }.to raise_error(::Aws::EC2::Errors::InvalidGroupNotFound)
      end

      it 'and should not fail to be applied multiple times' do
        success = PuppetManifest.new(@template, @config_2).apply[:exit_status].success?
        expect(success).to eq(true)
      end
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
            :protocol => 'udp',
            :port     => 22,
            :cidr     => '0.0.0.0/0'
          },
          {
            :protocol => 'tcp',
            :port     => 443,
            :cidr     => '0.0.0.0/0'
          },{
            :protocol => 'tcp',
            :port     => 22,
            :cidr     => '0.0.0.0/0'
          },
        ],
        :tags => {
          :department => 'engineering',
          :project    => 'cloud',
          :created_by => 'aws-acceptance'
        }
      }

      PuppetManifest.new(@template, @config).apply
      @group = get_group(@config[:name])
    end

    after(:each) do
      @config[:ensure] = 'absent'
      PuppetManifest.new(@template, @config).apply
      expect { get_group(@config[:name]) }.to raise_error(Aws::EC2::Errors::InvalidGroupNotFound)
    end

    def expect_rule_matches(ingress_rule, ip_permission)
      expect(ingress_rule[:protocol]).to eq(ip_permission.ip_protocol)
      expect(ingress_rule[:port]).to eq(ip_permission.to_port)
    end

    it 'and does not emit change notifications on a second run when the manifest ingress rule ordering does not match the one returned by AWS' do
      output = PuppetManifest.new(@template, @config).apply[:output]
      @group = get_group(@config[:name])

      # Puppet code not loaded, so can't call format_ingress_rules on ec2_securitygroup type
      expect_rule_matches(@config[:ingress][2], @group[:ip_permissions][0])
      expect_rule_matches(@config[:ingress][1], @group[:ip_permissions][1])
      expect_rule_matches(@config[:ingress][0], @group[:ip_permissions][2])

      # should still be considered insync despite ordering differences
      changed = output.any? { |l| l.match('ingress changed') }
      expect(changed).to eq(false)
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
      @group = get_group(@config[:name])
    end

    after(:each) do
      @config[:ensure] = 'absent'
      PuppetManifest.new(@template, @config).apply
      expect { get_group(@config[:name]) }.to raise_error(Aws::EC2::Errors::InvalidGroupNotFound)
    end

    it 'that can have tags changed' do
      pending 'changing tags not yet supported for security groups'
      expect(@aws.tag_difference(@group, @config[:tags])).to be_empty

      tags = {:created_by => 'aws-tests', :foo => 'bar'}
      @config[:tags].update(tags)

      PuppetManifest.new(@template, @config).apply
      @group = get_group(@config[:name])
      expect(@aws.tag_difference(@group, @config[:tags])).to be_empty
    end
  end

  describe 'create a security group' do

    before(:all) do
      @config = {
        :name         => "#{PuppetManifest.env_id}-#{SecureRandom.uuid}",
        :ensure       => 'present',
        :description  => 'A_security_group_used_in_an_automated_acceptance_test',
        :region       => @default_region,
      }
    end

    it 'create with puppet resource' do
      r = TestExecutor.puppet_resource('ec2_securitygroup', @config, '--modulepath ../')
      expect(r.stderr).not_to match(/Error:/)
      # assert with AWS SKD
      expect{get_group(@config[:name])}.not_to raise_error
    end

    it 'destroy with puppet resource' do
      @config[:ensure] = 'absent'
      TestExecutor.puppet_resource('ec2_securitygroup', @config, '--modulepath ../')
      expect { get_group(@config[:name]) }.to raise_error(Aws::EC2::Errors::InvalidGroupNotFound)
    end

  end

  describe 'create a new securitygroup with manifest' do
    # create with manifest, describe with puppet resource
    before(:all) do
      @config = {
        :name         => "#{PuppetManifest.env_id}-#{SecureRandom.uuid}",
        :ensure       => 'present',
        :description  => 'A_security group used in an automated acceptance test',
        :region       => @default_region,
        :ingress => [
          {
            :protocol => 'tcp',
            :port     => 22,
            :cidr     => '0.0.0.0/0'
          },
          {
            :security_group => 'default',
          }

        ],
        :tags => {
          :department => 'engineering',
          :project    => 'cloud',
          :created_by => 'aws-acceptance',
          :dude       => 'Sweet!',
        },
      }
      PuppetManifest.new(@template, @config).apply
      expect{get_group(@config[:name])}.not_to raise_error
      @response = TestExecutor.puppet_resource('ec2_securitygroup', {:name => @config[:name]}, '--modulepath ../')
      @group = get_group(@config[:name])
    end

    context 'describe ec2 securitygroup with puppet resource' do

      it 'ensure is correct' do
        regex = /(ensure)(\s*)(=>)(\s*)('#{@config[:ensure]}')/
        expect(@response.stdout).to match(regex)
      end

      it 'description is correct' do
        regex = /(description)(\s*)(=>)(\s*)('#{@config[:description]}')/
        expect(@response.stdout).to match(regex)
      end

      it 'region is correct' do
        regex = /(region)(\s*)(=>)(\s*)('#{@config[:region]}')/
        expect(@response.stdout).to match(regex)
      end

      it 'tags are correct' do
        pending('This test is blocked by CLOUD-203')
        @config[:tags].each do |tag, value|
          regex = /('#{tag.to_s}')(\s*)(=>)(\s*)('#{value}')/
          expect(@response.stdout).to match(regex)
        end
      end

      it 'ingress rules are correct' do
        @config[:ingress].each do |i|
          i.each do |key, value|
            regex = /('#{key}')(\s*)(=>)(\s*)('#{value}')/
            expect(@response.stdout).to match(regex)
          end
        end
      end

    end

    after(:all) do
      @config[:ensure] = 'absent'
      PuppetManifest.new(@template, @config).apply
      expect { get_group(@config[:name]) }.to raise_error(Aws::EC2::Errors::InvalidGroupNotFound)
    end

  end

end
