require 'spec_helper_acceptance'
require 'securerandom'

describe "rds_instance" do

  before(:all) do
    @default_region = 'sa-east-1'
    @aws = AwsHelper.new(@default_region)
    @template = 'rds.pp.tmpl'
  end

  def get_rds_instance(name)
    rds_instances = @aws.get_rds_instance(name)
    expect(rds_instances.count).to eq(1)
    rds_instances.first
  end

  describe 'should create a new RDS instance' do

    before(:all) do
      @config = {
        :name => "#{PuppetManifest.rds_id}-#{SecureRandom.hex}",
        :ensure => 'present',
        :region => @default_region,
        :db_name =>  'puppet',
        :engine => 'mysql',
        :allocated_storage => '5',
        :engine_version => '5.6.19a',
        :license_model => 'general-public-license',
        :availability_zone => 'us-west-2a',
        :storage_type => 'gp2',
        :db_instance_class => 'db.m3.medium',
        :master_username => 'puppet',
        :master_user_password => 'pullth3stringz',
        :multi_az => false,
      }

      manifest = PuppetManifest.new(@template, @config)
      manifest.apply
      @rds_instance = get_rds_instance(@config[:name])
    end

    after(:all) do
      new_config = @config.update({:ensure => 'absent'})
      PuppetManifest.new(@template, new_config).apply
    end

    it "with the specified name" do
      expect(@rds_instance.db_instance_identifier).to eq(@config[:name])
    end

    it "with the specified db_name" do
      expect(@rds_instance.db_name).to eq(@config[:db_name])
    end

    it "with the specified engine" do
      expect(@rds_instance.engine).to eq(@config[:engine])
    end

  end
end