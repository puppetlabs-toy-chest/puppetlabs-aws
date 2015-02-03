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
      @config[:optional] = {:key_name => ENV['AWS_KEY_PAIR']} if ENV['AWS_KEY_PAIR']

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

    context 'using puppet resource to describe' do

      before(:all) do
        #reset to known state
         r = PuppetManifest.new(@template, @config).apply
         expect(r[:output].any?{ |o| o.include?('Error:')}).to eq(false)
      end

      context 'CloudWatch alarm' do

        before(:all) do
          ENV['AWS_REGION'] = @default_region
          options = {:name => "#{@config[:name]}-AddCapacity"}
          @result = TestExecutor.puppet_resource('cloudwatch_alarm', options, '--modulepath ../')
          @cw = find_alarm("#{@config[:name]}-AddCapacity")
        end

        it 'metric is correct' do
          regex = /metric\s*=>\s*'#{@cw.metric_name}'/
          expect(@result.stdout).to match(regex)
        end

        it 'namespace is corect' do
          regex = /namespace\s*=>\s*'#{@cw.namespace}'/
          expect(@result.stdout).to match(regex)
        end

        it 'statistic is correct' do
          regex = /statistic\s*=>\s*'#{@cw.statistic}'/
          expect(@result.stdout).to match(regex)
        end

        it 'period is corrrect' do
          regex = /period\s*=>\s*'#{@cw.period}'/
          expect(@result.stdout).to match(regex)
        end

        it 'threshold is correct' do
          regex = /threshold\s*=>\s*'#{@cw.threshold}'/
          expect(@result.stdout).to match(regex)
        end

        it 'comparison_operator' do
          regex = /comparison_operator\s*=>\s*'#{@cw.comparison_operator}'/
          expect(@result.stdout).to match(regex)
        end

        it 'dimensions' do
          expect(@cw.dimensions.all?{ |d| /#{d.value}/.match(@result.stdout) }).to eq(true)
        end

        it 'evaluation_periods' do
          regex = /evaluation_periods\s*=>\s*'#{@cw.evaluation_periods}'/
          expect(@result.stdout).to match(regex)
        end

      end

      context 'autoscaling group' do

        before(:all) do
          ENV['AWS_REGION'] = @default_region
          options = {:name => "#{@config[:name]}-asg"}
          @result = TestExecutor.puppet_resource('ec2_autoscalinggroup', options, '--modulepath ../')
          @asg = find_autoscaling_group("#{@config[:name]}-asg")
        end

        it 'min_size' do
          regex = /min_size\s*=>\s*'#{@asg.min_size}'/
          expect(@result.stdout).to match(regex)
        end

        it 'max_size' do
          regex = /max_size\s*=>\s*'#{@asg.max_size}'/
          expect(@result.stdout).to match(regex)
        end

        it 'launch_configuration' do
          regex = /launch_configuration\s*=>\s*'#{@asg.launch_configuration_name }'/
          expect(@result.stdout).to match(regex)
        end

        it 'instance_count' do
          regex = /instance_count\s*=>\s*'#{@asg.instances.count}'/
          expect(@result.stdout).to match(regex)
        end

        it 'availability_zones' do
          ["#{@default_region}a", "#{@default_region}b"].each do |az|
            regex = /'#{az}'/
            expect(@result.stdout).to match(regex)
          end
        end

      end

      context 'launch_configuration' do

        before(:all) do
          ENV['AWS_REGION'] = @default_region
          options = {:name => "#{@config[:name]}-lc"}
          @result = TestExecutor.puppet_resource('ec2_launchconfiguration', options, '--modulepath ../')
          @lc = find_launch_config("#{@config[:name]}-lc")
        end

        it 'security_groups' do
          @lc.security_groups.each do |sg|
            expect(@result.stdout).to match(/#{sg}/)
          end
        end

        it 'key_name' do
          if ENV['AWS_KEY_PAIR']
            # key was supplied at creation of asg
            # key should be reported
            # we will need a key to run this with in CI
            regex = /(key_name)(\s*)(=>)(\s*)('#{@lc.key_name}')/
            expect(@result.stdout).to match(regex)
          else
            # no key was supplied on creation of asg
            # should not report key
            regex = /key_name/
            expect(@result.stdout).not_to match(regex)
          end
        end

        it 'instance_type' do
          regex = /instance_type\s*=>\s*'#{@lc.instance_type}'/
          expect(@result.stdout).to match(regex)
        end

        it 'image_id' do
          regex = /image_id\s*=>\s*'#{@lc.image_id}'/
          expect(@result.stdout).to match(regex)
        end

      end

      context 'scaling policy' do

        before(:all) do
          ENV['AWS_REGION'] = @default_region
          options = {:name => "#{@config[:name]}-scaleout"}
          @result = TestExecutor.puppet_resource('ec2_scalingpolicy', options, '--modulepath ../')
          @sp = find_scaling_policy("#{@config[:name]}-scaleout", "#{@config[:name]}-asg")
        end

        it 'scaling_adjustment' do
          regex = /scaling_adjustment\s*=>\s*'#{@sp.scaling_adjustment}'/
          expect(@result.stdout).to match(regex)
        end

        it 'adjustment_type' do
          regex = /adjustment_type\s*=>\s*'#{@sp.adjustment_type}'/
          expect(@result.stdout).to match(regex)
        end

        it 'ec2_autoscaling_group' do
          regex = /auto_scaling_group\s*=>\s*'#{@sp.auto_scaling_group_name}'/
          expect(@result.stdout).to match(regex)
        end

      end

    end

  end

  describe 'create an autoscaling_group' do

    before(:all) do
      name = "#{PuppetManifest.env_id}-#{SecureRandom.uuid}"
      @asg_template = 'autoscaling_configurable.pp.tmpl'
      @asg_template_delete = 'autoscaling_configurable_delete.pp.tmpl'
      @duplicate_asg_template = 'autoscaling_duplicate.pp.tmpl'
      @sg_delete = 'sg_delete.pp.tmpl'
      # launch configurable stack
      @asg_config = {
        :ensure               => 'present',
        :region               => @default_region,
        :sg_name              => "#{name}-sg",
        :lc_name              => "#{name}-lc",
        :sg_setting           => "#{name}-sg",
        :asg_name             => "#{name}-asg",
        :min_size             => 2,
        :max_size             => 6,
        :lc_setting           => "#{name}-lc",
        :availability_zones   => ["#{@default_region}a", "#{@default_region}b"],
        :policy_name          => "#{name}-policy",
        :second_policy_name   => "#{name}-second_policy",
        :asg_setting          => "#{name}-asg",
        :scaling_adjustment   => 30,
        :adjustment_type      => 'PercentChangeInCapacity',
        :alarm_name           => "#{name}-cw_alarm",
        :metric               => 'CPUUtilization',
        :namespace            => 'AWS/EC2',
        :statistic            => 'Average',
        :period               => 120,
        :threshold            => 70,
        :comparison_operator  => 'GreaterThanOrEqualToThreshold',
        :asg_setting          => "#{name}-asg",
        :evaluation_periods   => 2,
        :alarm_actions        => "#{name}-policy",
      }
      r = PuppetManifest.new(@asg_template, @asg_config).apply
      expect(r[:output].any?{ |o| o.include?('Error:')}).to eq(false)
      # launch duplicate resources
      @duplicate_asg_config = {
        :region       => @default_region,
        :sg_name      => "#{name}-sg2",
        :lc_name      => "#{name}-lc2",
        :alarm_name   => "#{name}-cw_alarm2",
        :asg_name     => "#{name}-asg_name2",
        :policy_name  => "#{name}-policy_name2",
      }
      r2 = PuppetManifest.new(@duplicate_asg_template, @duplicate_asg_config).apply
      expect(r2[:output].any?{ |o| o.include?('Error:')}).to eq(false)
    end

    after(:all) do
      @asg_config[:ensure] = 'absent'
      @duplicate_asg_config[:ensure] = 'absent'
      r = PuppetManifest.new(@asg_template_delete, @asg_config).apply
      r2 = PuppetManifest.new(@asg_template_delete, @duplicate_asg_config).apply
      # assert that none of the results contain 'Error:'
      expect(r[:output].any?{ |o| o.include?('Error:')}).to eq(false)
      expect(r2[:output].any?{ |o| o.include?('Error:')}).to eq(false)
      # TODO add logic to wait for ec2instances to teardown
      # TODO add teardown of security groups
    end

    context 'modify cloudwatch property' do

      it 'metric' do
        config = @asg_config.clone
        config[:metric] = 'NetworkIn'
        r = PuppetManifest.new(@asg_template, config).apply
        expect(r[:output].any?{ |o| o.include?('Error:')}).to eq(false)
        cloudwatch = find_alarm(@asg_config[:alarm_name])
        expect(cloudwatch.metric_name).to eq('NetworkIn')
      end

      it 'namespace and metric' do
        # TODO complicated

      end

      it 'statistic' do
        config = @asg_config.clone
        config[:statistic] = 'Sum'
        r = PuppetManifest.new(@asg_template, config).apply
        expect(r[:output].any?{ |o| o.include?('Error:')}).to eq(false)
        cloudwatch = find_alarm(@asg_config[:alarm_name])
        expect(cloudwatch.statistic).to eq('Sum')
      end

      #it 'period' do
      #  config = @asg_config.clone
      #  config[:period] = 180
      #  r = PuppetManifest.new(@asg_template, config).apply
      #  expect(r[:output].any?{ |o| o.include?('Error:')}).to eq(false)
      #  cloudwatch = find_alarm(@asg_config[:alarm_name])
      #  expect(cloudwatch.period).to eq(180)
      #end

      it 'evaluation_periods' do
        config = @asg_config.clone
        config[:evaluation_periods] = 4
        r = PuppetManifest.new(@asg_template, config).apply
        expect(r[:output].any?{ |o| o.include?('Error:')}).to eq(false)
        cloudwatch = find_alarm(@asg_config[:alarm_name])
        expect(cloudwatch.evaluation_periods).to eq(4)
      end

      #it 'threshold' do
      #  config = @asg_config.clone
      #  config[:threshold] = 50
      #  r = PuppetManifest.new(@asg_template, config).apply
      #  expect(r[:output].any?{ |o| o.include?('Error:')}).to eq(false)
      #  cloudwatch = find_alarm(@asg_config[:alarm_name])
      #  expect(cloudwatch.threshold).to eq(50.0)
      #end

      it 'comparison_operator' do
        config = @asg_config.clone
        config[:comparison_operator] = 'GreaterThanThreshold'
        r = PuppetManifest.new(@asg_template, config).apply
        expect(r[:output].any?{ |o| o.include?('Error:')}).to eq(false)
        cloudwatch = find_alarm(@asg_config[:alarm_name])
        expect(cloudwatch.comparison_operator).to eq('GreaterThanThreshold')
      end

      it 'dimensions' do
        pending('CLOUD-216')
        config = @asg_config.clone
        config[:asg_setting] = @duplicate_asg_config[:asg_name]
        r = PuppetManifest.new(@asg_template, config).apply
        expect(r[:output].any?{ |o| o.include?('Error:')}).to eq(false)
        cloudwatch = find_alarm(@asg_config[:alarm_name])
        expect(cloudwatch.dimensions.any?{ |d| d.value == @duplicate_asg_config[:asg_name]}).to eq(true)
      end

      it 'alarm_actions' do
        pending('CLOUD-217')
        config = @asg_config.clone
        config[:alarm_actions] = @asg_config[:second_policy_name]
        r = PuppetManifest.new(@asg_template, config).apply
        expect(r[:output].any?{ |o| o.include?('Error:')}).to eq(false)
        cloudwatch = find_alarm(@asg_config[:alarm_name])
        expect(cloudwatch.alarm_actions.any?{ |a| a.include? @asg_config[:second_policy_name]}).to eq(true)
      end

    end

    context 'modify ec2_scalingpolicy' do

      #it 'scaling_adjustment' do
      #  config = @asg_config.clone
      #  config[:scaling_adjustment] = 40
      #  r = PuppetManifest.new(@asg_template, config).apply
      #  expect(r[:output].any?{ |o| o.include?('Error:')}).to eq(false)
      #  policy = find_scaling_policy(@asg_config[:policy_name], @asg_config[:asg_name])
      #  expect(policy.scaling_adjustment).to eq(40)
      #end

      #it 'adjustment_type' do
      #  config = @asg_config.clone
      #  config[:adjustment_type] = 'ExactCapacity'
      #  r = PuppetManifest.new(@asg_template, config).apply
      #  expect(r[:output].any?{ |o| o.include?('Error:')}).to eq(false)
      #  policy = find_scaling_policy(@asg_config[:policy_name], @asg_config[:asg_name])
      #  expect(policy.adjustment_type).to eq('ExactCapacity')
      #end

      it 'auto_scaling_group' do
        pending('shouldnt be possible??? CLOUD-218')
        config = @asg_config.clone
        config[:asg_setting] = @duplicate_asg_config[:asg_name]
        r = PuppetManifest.new(@asg_template, config).apply
        expect(r[:output].any?{ |o| o.include?('Error:')}).to eq(false)
        policy = find_scaling_policy(@asg_config[:policy_name], @asg_config[:asg_name])
        expect(policy.auto_scaling_group_name).to eq(@duplicate_asg_config[:asg_name])
      end

    end

    context 'modify ec2_autoscalinggroup' do

      #it 'min_size' do
      #  config = @asg_config.clone
      #  config[:min_size] = 3
      #  r = PuppetManifest.new(@asg_template, config).apply
      #  expect(r[:output].any?{ |o| o.include?('Error:')}).to eq(false)
      #  group = find_autoscaling_group(@asg_config[:asg_name])
      #  expect(group.min_size).to eq(3)
      #end

      #it 'max_size' do
      #  config = @asg_config.clone
      #  config[:max_size] = 5
      #  r = PuppetManifest.new(@asg_template, config).apply
      #  expect(r[:output].any?{ |o| o.include?('Error:')}).to eq(false)
      #  group = find_autoscaling_group(@asg_config[:asg_name])
      #  expect(group.max_size).to eq(5)
      #end

      it 'launch_configuration' do
        config = @asg_config.clone
        config[:lc_setting] = @duplicate_asg_config[:lc_name]
        r = PuppetManifest.new(@asg_template, config).apply
        expect(r[:output].any?{ |o| o.include?('Error:')}).to eq(false)
        group = find_autoscaling_group(@asg_config[:asg_name])
        expect(group.launch_configuration_name).to eq(@duplicate_asg_config[:lc_name])
      end

      it 'availability_zones' do
        config = @asg_config.clone
        config[:availability_zones] = ["#{@default_region}b"]
        r = PuppetManifest.new(@asg_template, config).apply
        expect(r[:output].any?{ |o| o.include?('Error:')}).to eq(false)
        group = find_autoscaling_group(@asg_config[:asg_name])
        expect(group.availability_zones.sort).to eq(config[:availability_zones].sort)
      end

    end

  end

end
