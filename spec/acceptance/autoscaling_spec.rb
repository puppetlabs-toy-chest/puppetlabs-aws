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
          expect(@result.stdout).to match(regex)
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

end
