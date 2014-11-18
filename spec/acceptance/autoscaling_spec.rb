require 'spec_helper_acceptance'
require 'securerandom'

describe "ec2_autoscalinggroup" do

  before(:all) do
    @default_region = 'sa-east-1'
    @aws = Ec2Helper.new(@default_region)
  end

  def find_autoscaling_group(name)
    groups = @aws.get_autoscaling_groups(name)
    expect(groups.count).to eq(1)
    groups.first
  end

  def find_launch_config(name)
    config = @aws.get_launch_configs(name)
    expect(config.count).to eq(1)
    config.first
  end

  def find_scaling_policy(name, group)
    policy = @aws.get_scaling_policies(name, group)
    expect(policy.count).to eq(1)
    policy.first
  end

  def find_alarm(name)
    alarm = @aws.get_alarms(name)
    expect(alarm.count).to eq(1)
    alarm.first
  end

  describe 'should create a new autoscaling group' do

    before(:all) do
      @name = "#{PuppetManifest.env_id}-#{SecureRandom.uuid}"
      @config = {
        :name => @name,
        :ensure => 'present',
      }

      template = 'autoscaling.pp.tmpl'
      PuppetManifest.new(template, @config).apply
    end

    after(:all) do
      new_config = @config.update({:ensure => 'absent'})
      template = 'autoscaling_delete.pp.tmpl'
      PuppetManifest.new(template, new_config).apply
    end

    it 'should create an auto scaling group' do
      find_autoscaling_group("#{@name}-asg")
    end

    it 'should create a launch configuration' do
      find_launch_config("#{@name}-lc")
    end

    it 'should create CloudWatch alarms' do
      find_alarm("#{@name}-AddCapacity")
      find_alarm("#{@name}-RemoveCapacity")
    end

    it 'should create scaling policies' do
      find_scaling_policy("#{@name}-scaleout", "#{@name}-asg")
      find_scaling_policy("#{@name}-scalein", "#{@name}-asg")
    end

  end

end
