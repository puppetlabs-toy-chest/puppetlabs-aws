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
      @group = find_group(@config[:name])
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
      has_matching_tags(@group, @config[:tags])
    end

    it "with the specified description" do
      expect(@group.description).to eq(@config[:description])
    end

  end

end
