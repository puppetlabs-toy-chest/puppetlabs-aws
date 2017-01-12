#require 'spec_helper_acceptance'
#require 'securerandom'
#
#describe 'iam_instance_profile' do
#  before(:all) do
#    @default_region = 'us-east-1'
#    @aws = AwsHelper.new(@default_region)
#    @template = 'iam_instance_profile.pp.tmpl'
#  end
#
#  def get_role(name)
#    roles = @aws.get_iam_roles(name)
#    expect(roles.count).to eq(1)
#    roles.first
#  end
#
#  def get_instance_profile(name)
#    instance_profiles = @aws.get_iam_instance_profiles(name)
#    expect(instance_profiles.count).to eq(1)
#    instance_profiles.first
#  end
#
#  describe 'managing as puppet resource' do
#    before :all do
#      @name = "#{SecureRandom.uuid}"
#
#      @config = {
#          :role_name => @name,
#          :profile_name => @name,
#          :path_prefix => "/#{SecureRandom.hex(8)}/",
#          :ensure => 'present',
#      }
#    end
#
#    it "should create properly with only defaults" do
#      profile_options = { :name => @config[:profile_name], :path => @config[:path_prefix], :ensure => @config[:ensure] }
#      result = TestExecutor.puppet_resource('iam_instance_profile', profile_options, '--modulepath spec/fixtures/modules/')
#      expect(result.stderr).not_to match(/Error:/)
#    end
#
#    it "should have the specified name" do
#      profile = get_instance_profile(@config[:profile_name])
#      expect(profile.instance_profile_name).to eq(@config[:profile_name])
#    end
#
#    it "should have a valid ARN" do
#      profile = get_instance_profile(@config[:profile_name])
#      expect(profile.arn).to match(/^arn\:aws\:iam\:\:\d+\:\S+$/)
#      expect(profile.arn).to include("#{@config[:path]}#{@config[:profile_name]}")
#    end
#
#    it "should accept a role assignment after the fact" do
#      role_options = { :name => @config[:role_name], :path => @config[:path_prefix], :ensure => @config[:ensure] }
#      result = TestExecutor.puppet_resource('iam_role', role_options, '--modulepath spec/fixtures/modules/ --trace')
#      expect(result.stderr).not_to match(/Error:/)
#
#      profile_options = { :name => @config[:profile_name], :path => @config[:path_prefix], :ensure => @config[:ensure], :roles => @config[:role_name] }
#      result = TestExecutor.puppet_resource('iam_instance_profile', profile_options, '--modulepath spec/fixtures/modules/ --trace')
#      expect(result.stderr).not_to match(/Error:/)
#    end
#
#    it "should accept policy attachment" do
#      policy_options = { :name => 'IAMFullAccess', :roles => @config[:role_name] }
#      result = TestExecutor.puppet_resource('iam_policy_attachment', policy_options, '--modulepath spec/fixtures/modules/ --trace')
#      expect(result.stderr).not_to match(/Error:/)
#    end
#
#    it "should destroy and cleanup properly" do
#      new_config = @config.update({:ensure => 'absent'})
#
#      role_options = { :name => new_config[:role_name], :path => @config[:path_prefix], :ensure => new_config[:ensure] }
#      result = TestExecutor.puppet_resource('iam_role', role_options, '--modulepath spec/fixtures/modules/ --trace')
#      expect(result.stderr).not_to match(/Error:/)
#
#      profile_options = { :name => new_config[:profile_name], :path => @config[:path_prefix], :ensure => new_config[:ensure] }
#      result = TestExecutor.puppet_resource('iam_instance_profile', profile_options, '--modulepath spec/fixtures/modules/ --trace')
#      expect(result.stderr).not_to match(/Error:/)
#    end
#
#  end
#
#  describe 'managing via puppet manifest apply' do
#
#    before (:all) do
#      @name = "#{SecureRandom.uuid}"
#      @path_prefix = "/#{SecureRandom.hex(8)}/"
#      @role_policy_json = <<-'JSON'
#          {
#            "Version": "2012-10-17",
#            "Statement": [
#              {
#                "Effect": "Allow",
#                "Principal": {
#                  "Service": "ec2.amazonaws.com"
#                },
#                "Action": "sts:AssumeRole"
#              }
#            ]
#          }
#      JSON
#
#      @config = {
#          :role_name => @name,
#          :profile_name => @name,
#          :path => @path_prefix,
#          :role_policy_document => @role_policy_json.strip.gsub(/\r\n?/, " "),
#          :ensure => 'present',
#      }
#    end
#
#    it "should compile and apply" do
#      result = PuppetManifest.new(@template, @config).apply
#      expect(result.stderr).not_to match(/Error:/)
#    end
#
#    it "with the specified name" do
#      profile = get_instance_profile(@config[:profile_name])
#      expect(profile.instance_profile_name).to eq(@config[:profile_name])
#    end
#
#    it "should have valid ARN" do
#      profile = get_instance_profile(@config[:profile_name])
#      expect(profile.arn).to match(/^arn\:aws\:iam\:\:\d+\:\S+$/)
#      expect(profile.arn).to include("#{@config[:path]}#{@config[:profile_name]}")
#    end
#
#    it "should cleanup properly" do
#      new_config = @config.update({:ensure => 'absent'})
#      result = PuppetManifest.new(@template, new_config).apply
#      expect(result.stderr).not_to match(/Error:/)
#    end
#  end
#
#end
