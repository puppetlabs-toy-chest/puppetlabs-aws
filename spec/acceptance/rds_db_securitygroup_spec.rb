require 'spec_helper_acceptance'
require 'securerandom'

describe "rds_db_securitygroup" do

  before(:all) do
    @default_region = 'sa-east-1'
    @aws = AwsHelper.new(@default_region)
    @template = 'rds_db_securitygroup.pp.tmpl'
  end

  def get_db_securitygroup(name)
    db_security_groups = @aws.get_db_security_groups(name)
    expect(db_security_groups.count).to eq(1)
    db_security_groups.first
  end

  describe 'should create a new RDS db_securitygroup instance' do

    before(:all) do
      @config = {
        :name   => "#{PuppetManifest.rds_id}-#{SecureRandom.hex}",
        :ensure => 'present',
        :region => @default_region,
        :db_security_group_description => 'Acceptance test',
      }

      manifest = PuppetManifest.new(@template, @config)
      manifest.apply
      @db_securitygroup = get_db_securitygroup(@config[:name])
    end

    after(:all) do
      new_config = @config.update({:ensure => 'absent'})
      PuppetManifest.new(@template, new_config).apply
    end

    it "with the specified name" do
      expect(@db_securitygroup.db_security_group_name).to eq(@config[:name])
    end

    it "with the specified db_security_group_description" do
      expect(@db_securitygroup.db_security_group_description).to eq(@config[:db_security_group_description])
    end

  end
end