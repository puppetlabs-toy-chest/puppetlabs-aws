require 'spec_helper_acceptance'
require 'securerandom'

describe "ec2_instance" do

  before(:all) do
    @config = {
      :name => "#{PuppetManifest.env_id}-#{SecureRandom.uuid}",
      :instance_type => 't1.micro',
      :region => 'sa-east-1',
      :image_id => 'ami-41e85d5c',
      :ensure => 'present',
    }
    @ec2 = Ec2Helper.new(@config[:region])
    @template = 'instance.pp.tmpl'
    PuppetManifest.new(@template, @config).apply
  end

  after(:all) do
    wait_until_status(@config[:name], 'running')

    new_config = @config.update({:ensure => 'absent'})
    PuppetManifest.new(@template, new_config).apply

    wait_until_status(@config[:name], 'shutting-down')
  end

  def find_instance(name)
    instances = @ec2.get_instances(name)
    expect(instances.count).to eq(1)
    instances.first
  end

  def wait_until_status(name, status, max_wait = 15)
    slept = 0

    loop do
      current_status = find_instance(name).state.name
      break if current_status == status

      sleep(1)
      slept += 1

      if slept > max_wait
        msg = "Exceeded timeout of #{max_wait} waiting for #{name} to be #{status}"
        expect(current_status).to eq(status), msg
      end
    end
  end

  describe 'should create a new instance' do

    before(:all) do
      @instance = find_instance(@config[:name])
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
