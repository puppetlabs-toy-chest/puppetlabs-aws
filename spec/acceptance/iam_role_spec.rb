require 'spec_helper_acceptance'
require 'securerandom'

describe 'iam_role' do
  before(:all) do
    @default_region = 'us-east-1'
    @aws = AwsHelper.new(@default_region)
  end

  def find_role(name)
    roles = @aws.get_iam_roles(name)
    expect(roles.count).to eq(1)
    roles.first
  end

  describe 'manage an iam_role' do

    before (:all) do
      @name = "#{SecureRandom.uuid}"
      @config = {
          :name => @name,
      }
    end

    it 'with puppet resource' do
      options = {:name => @config[:name], :ensure => 'present'}
      result = TestExecutor.puppet_resource('iam_role', options, '--modulepath spec/fixtures/modules/')
      expect(result.stderr).not_to match(/Error:/)
      expect{ find_role(@config[:name]) }.not_to raise_error
    end

    it 'should create an IAM role with the correct name' do
      role = find_role(@name)
      expect(role.role_name).to eq(@name)
    end

    it 'should create an IAM role with a valid ARN' do
      role = find_role(@name)
      expect(role.arn).to match(/^arn\:aws\:iam\:\:\d+\:\S+$/)
    end

    it 'should destroy an IAM role' do
      options = {:name => @config[:name], :ensure => 'absent'}
      result = TestExecutor.puppet_resource('iam_role', options, '--modulepath spec/fixtures/modules/')
      expect(result.stderr).not_to match(/Error:/)
      expect(@aws.get_iam_roles(@name)).to be_empty
    end

  end

end
