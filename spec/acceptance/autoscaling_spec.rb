require 'spec_helper_acceptance'
require 'securerandom'

describe "ec2_autoscalinggroup" do

  before(:all) do
    @default_region = 'sa-east-1'
    @aws = AwsHelper.new(@default_region)
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
        :min_size => 2,
        :max_size => 4,
        :image_id => 'ami-67a60d7a',
        :metric => 'CPUUtilization',
        :namespace => 'AWS/EC2',
        :statistic => 'Average',
        :period => 120,
        :threshold => 70,
        :comparison_operator => 'GreaterThanOrEqualToThreshold',
        :evaluation_periods => 2,
        :adjustment_type => 'PercentChangeInCapacity',
        :scaling_adjustment => 30,
      }

      @template = 'autoscaling.pp.tmpl'
      PuppetManifest.new(@template, @config).apply
    end

    after(:all) do
      new_config = @config.update({:ensure => 'absent'})
      template = 'autoscaling_delete.pp.tmpl'
      PuppetManifest.new(template, new_config).apply
      # wait for all instances under ASG to be terminated
      response = @aws.autoscaling_client.describe_auto_scaling_groups(
        auto_scaling_group_names: ["#{@name}-asg"],
      )
      id = Array.new
      response.to_h[:auto_scaling_groups].first[:instances].each do |x|
        id.push(x[:instance_id])
      end
      @aws.ec2_client.wait_until(:instance_terminated, instance_ids: id)
      # delete the security group
      sg_template = 'sg_delete.pp.tmpl'
      sg_config = {
        :ensure   => 'absent',
        :name     => @name,
        :region   => @default_region
      }
      PuppetManifest.new(sg_template, sg_config).apply
    end

    it 'should run idempotently' do
      success = PuppetManifest.new(@template, @config).apply[:exit_status].success?
      expect(success).to eq(true)
    end

    context 'should create an auto scaling group' do
      before(:all) do
        @group = find_autoscaling_group("#{@name}-asg")
      end
      it 'with the correct properties' do
        expect(@group.min_size).to eq(@config[:min_size])
        expect(@group.max_size).to eq(@config[:max_size])
        expect(@group.launch_configuration_name).to eq("#{@name}-lc")
        expect(@group.availability_zones).to eq(['sa-east-1a', 'sa-east-1b'])
      end

      it 'with min and max size properties that can be changed' do
        new_min_size = 1
        new_max_size = 1
        expect(new_min_size).not_to eq(@config[:min_size])
        expect(new_max_size).not_to eq(@config[:max_size])
        new_config = @config.update({:min_size => new_min_size, :max_size => new_max_size})
        PuppetManifest.new(@template, new_config).apply
        group = find_autoscaling_group("#{@name}-asg")
        expect(group.min_size).to eq(new_min_size)
        expect(group.max_size).to eq(new_max_size)
      end
    end

    context 'should create a launch configuration' do
      before(:all) do
        @lc = find_launch_config("#{@name}-lc")
      end
      it 'with the correct properties' do
        expect(@lc.image_id).to eq('ami-67a60d7a')
        expect(@lc.instance_type).to eq('t1.micro')
      end
    end

    context 'should create CloudWatch alarms' do
      before(:all) do
        @alarm = find_alarm("#{@name}-AddCapacity")
      end

      it 'with the correct properties' do
        expect(@alarm.namespace).to eq(@config[:namespace])
        expect(@alarm.statistic).to eq(@config[:statistic])
        expect(@alarm.period).to eq(@config[:period])
        expect(@alarm.threshold).to eq(@config[:threshold])
        expect(@alarm.comparison_operator).to eq(@config[:comparison_operator])
        expect(@alarm.evaluation_periods).to eq(@config[:evaluation_periods])
      end

      it 'with properties that can be changed' do
        new_period = 180
        new_threshold = 60
        expect(new_period).not_to eq(@config[:period])
        expect(new_threshold).not_to eq(@config[:threshold])
        new_config = @config.update({
          :period => new_period,
          :threshold => new_threshold
        })
        PuppetManifest.new(@template, new_config).apply
        alarm = find_alarm("#{@name}-AddCapacity")
        expect(alarm.period).to eq(new_period)
        expect(alarm.threshold).to eq(new_threshold)
      end

    end

    context 'should create scaling policies' do
      before(:all) do
        @policy = find_scaling_policy("#{@name}-scaleout", "#{@name}-asg")
      end

      it 'with the correct properties' do
        expect(@policy.adjustment_type).to eq(@config[:adjustment_type])
        expect(@policy.scaling_adjustment).to eq(@config[:scaling_adjustment])
        expect(@policy.auto_scaling_group_name).to eq("#{@name}-asg")
      end

      it 'with properties that can be changed' do
        new_scaling_adjustment = 2
        new_adjustment_type = 'ChangeInCapacity'
        expect(new_scaling_adjustment).not_to eq(@config[:scaling_adjustment])
        expect(new_adjustment_type).not_to eq(@config[:adjustment_type])
        new_config = @config.update({
          :scaling_adjustment => new_scaling_adjustment,
          :adjustment_type => new_adjustment_type
        })
        PuppetManifest.new(@template, new_config).apply
        policy = find_scaling_policy("#{@name}-scaleout", "#{@name}-asg")
        expect(policy.adjustment_type).to eq(new_adjustment_type)
        expect(policy.scaling_adjustment).to eq(new_scaling_adjustment)
      end

    end

  end

end
