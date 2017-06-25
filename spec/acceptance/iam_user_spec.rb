#require 'spec_helper_acceptance'
#require 'securerandom'
#
#describe 'iam_user' do
#  before(:all) do
#    @default_region = 'sa-east-1'
#    @aws = AwsHelper.new(@default_region)
#  end
#
#  def find_user(name)
#    users = @aws.find_iam_users(name)
#    expect(users.count).to eq(1)
#    users.first
#  end
#
#  describe 'manage an iam_user' do
#
#    before (:all) do
#      @name = "#{SecureRandom.uuid}.com."
#      @config = {
#        :name => @name,
#      }
#      @template = 'iam_user.pp.tmpl'
#      @user = find_user(@name)
#    end
#
#    it 'with puppet resource' do
#      options = {:name => @config[:name], :ensure => 'present'}
#      result = TestExecutor.puppet_resource('iam_user', options, '--modulepath spec/fixtures/modules/')
#      expect(result.stderr).not_to match(/Error:/)
#      expect{ find_user(@config[:name]) }.not_to raise_error
#    end
#
#    it 'should run idempotently' do
#      result = PuppetManifest.new(@template, @config).apply
#      expect(result.exit_code).to eq(0)
#    end
#
#    it 'should create an IAM user with the correct name' do
#      expect(user.user_name).to eq(@name)
#    end
#
#    it 'should destroy an IAM user' do
#      options = {:name => @config[:name], :ensure => 'absent'}
#      TestExecutor.puppet_resource('iam_user', options, '--modulepath spec/fixtures/modules/')
#      expect(@aws.get_iam_users(@name)).to be_empty
#    end
#
#    it 'should run idempotently after destroy' do
#      result = PuppetManifest.new(@template, @config).apply
#      expect(result.exit_code).to eq(0)
#    end
#
#  end
#
#end
