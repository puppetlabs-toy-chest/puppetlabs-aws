require 'spec_helper_acceptance'
require 'securerandom'

describe "ec2_instance" do

  before(:all) do
    @config = {
      :name => "#{SecureRandom.uuid}-instance",
      :instance_type => 't1.micro',
      :region => 'sa-east-1',
      :image_id => 'ami-41e85d5c',
      :ensure => 'present',
    }
    @template = 'instance.pp'
    PuppetManifest.new(@template, @config).apply
  end

  after(:all) do
    new_config = @config.update({:ensure => 'absent'})
    PuppetManifest.new(@template, new_config).apply
  end

  describe 'should create a new instance' do

    before(:all) do
      ec2 = Ec2Helper.new(@config[:region])
      instances = ec2.get_instances(@config[:name])
      expect(instances.count).to eq(1)
      @instance = instances.first
    end

    it "with the specified name" do
      expect(@instance.tags.detect { |tag| tag.key == 'Name' }.value).to eq(@config[:name])
    end

    it "with the specified type" do
      expect(@instance.instance_type).to eq(@config[:instance_type])
    end

    it "with the specified AMI" do
      expect(@instance.image_id).to eq(@config[:image_id])
    end

  end

end
