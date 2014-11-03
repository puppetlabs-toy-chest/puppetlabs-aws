require 'spec_helper_acceptance'
require 'securerandom'

describe "ec2_securitygroup" do

  before(:all) do
    @default_region = 'sa-east-1'
    @aws = AWSHelper.new(@default_region)
    @template = 'securitygroup.pp.tmpl'
  end

  describe 'should create a new security group' do

    before(:all) do
      @config = {
        :name => "#{PuppetManifest.env_id}-#{SecureRandom.uuid}",
        :region => @default_region,
        :ensure => 'present',
        :description => 'short lived group created by acceptance tests',
        :tags => {
          :department => 'engineering',
          :project    => 'cloud',
          :created_by => 'aws-acceptance'
        }
      }

      PuppetManifest.new(@template, @config).apply
      @group = @aws.get_group(@config[:name])
    end

    after(:all) do
      new_config = @config.update({:ensure => 'absent'})
      PuppetManifest.new(@template, new_config).apply
    end

    it "with the specified name" do
      expect(@group.group_name).to eq(@config[:name])
    end

    it "isn't attached to a VPC" do
      expect(@group.vpc_id).to eq(nil)
    end

    it "with the specified tags" do
      expect(@aws.tag_difference(@group, @config[:tags])).to be_empty
    end

    it "with the specified description" do
      expect(@group.description).to eq(@config[:description])
    end

  end

end
