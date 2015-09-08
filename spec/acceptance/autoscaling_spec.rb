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

  describe 'autoscaling_group and related types' do

    before(:all) do
      name = "#{PuppetManifest.env_id}-#{SecureRandom.uuid}"
      @asg_template = 'autoscaling_configurable.pp.tmpl'
      @asg_template_delete = 'autoscaling_configurable_delete.pp.tmpl'
      @duplicate_asg_template = 'autoscaling_duplicate.pp.tmpl'
      @sg_delete = 'sg_delete.pp.tmpl'
      # launch asg and related resources
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
      expect(r.stderr).not_to match(/error/i)
      # launch duplicate resources
      @duplicate_asg_config = {
        :region       => @default_region,
        :sg_name      => "#{name}-sg2",
        :lc_name      => "#{name}-lc2",
      }
      r2 = PuppetManifest.new(@duplicate_asg_template, @duplicate_asg_config).apply
      expect(r2.stderr).not_to match(/error/i)
    end

    after(:all) do
      #audit this entire teardown
      @asg_config[:ensure] = 'absent'
      @duplicate_asg_config[:ensure] = 'absent'
      duplicate_delete = 'duplicate_asg_delete.pp.tmpl'
      r = PuppetManifest.new(@asg_template_delete, @asg_config).apply
      # assert that none of the results contain 'Error:'
      expect(r.stderr).not_to match(/error/i)
      response = @aws.autoscaling_client.describe_auto_scaling_groups(
        auto_scaling_group_names: [@asg_config[:asg_name]],
      )
      id = Array.new
      response.data[:auto_scaling_groups].first[:instances].each do |x|
        id.push(x[:instance_id])
      end
      @aws.ec2_client.wait_until(:instance_terminated, instance_ids: id)
      # delete the security group
      options = {
        :ensure   => 'absent',
        :name     => @asg_config[:sg_name],
        :region   => @default_region
      }
      ENV['AWS_REGION'] = @default_region
      r2 = TestExecutor.puppet_resource('ec2_securitygroup', options, '--modulepath ../')
      expect(r2.stderr).not_to match(/error/i)
      # terminate duplicate resources
      r3 = PuppetManifest.new(duplicate_delete, @duplicate_asg_config).apply
      expect(r3.stderr).not_to match(/error/i)
    end

    it 'should run idempotently' do
      result = PuppetManifest.new(@asg_template, @asg_config).apply
      expect(result.exit_code).to eq(0)
    end

    context 'should create' do

      context 'an auto scaling group' do

        before(:all) do
          @group = find_autoscaling_group(@asg_config[:asg_name])
        end

        it 'with the correct properties' do
          expect(@group.min_size).to eq(@asg_config[:min_size])
          expect(@group.max_size).to eq(@asg_config[:max_size])
          expect(@group.launch_configuration_name).to eq(@asg_config[:lc_setting])
          expect(@group.availability_zones).to eq(['sa-east-1a', 'sa-east-1b'])
        end

      end

      context 'a launch configuration' do

        before(:all) do
          @lc = find_launch_config(@asg_config[:lc_name])
        end

        it 'with the correct properties' do
          expect(@lc.image_id).to eq('ami-67a60d7a')
          expect(@lc.instance_type).to eq('t1.micro')
        end

      end

      context 'a CloudWatch alarm' do

        before(:all) do
          @alarm = find_alarm(@asg_config[:alarm_name])
        end

        it 'with the correct properties' do
          expect(@alarm.namespace).to eq(@asg_config[:namespace])
          expect(@alarm.statistic).to eq(@asg_config[:statistic])
          expect(@alarm.period).to eq(@asg_config[:period])
          expect(@alarm.threshold).to eq(@asg_config[:threshold])
          expect(@alarm.comparison_operator).to eq(@asg_config[:comparison_operator])
          expect(@alarm.evaluation_periods).to eq(@asg_config[:evaluation_periods])
        end

      end

      context 'should create scaling policies' do

        before(:all) do
          @policy = find_scaling_policy(@asg_config[:policy_name], @asg_config[:asg_name])
        end

        it 'with the correct properties' do
          expect(@policy.adjustment_type).to eq(@asg_config[:adjustment_type])
          expect(@policy.scaling_adjustment).to eq(@asg_config[:scaling_adjustment])
          expect(@policy.auto_scaling_group_name).to eq(@asg_config[:asg_name])
        end

      end

    end

    context 'using puppet resource to describe' do

      context 'CloudWatch alarm' do

        before(:all) do
          ENV['AWS_REGION'] = @default_region
          name = @asg_config[:alarm_name]
          options = {:name => name}
          @result = TestExecutor.puppet_resource('cloudwatch_alarm', options, '--modulepath ../')
          @cw = find_alarm(name)
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

        it 'alarm_actions' do
          regex = /alarm_actions\s*=>\s*\['#{@asg_config[:alarm_actions]}'\]/
          expect(@result.stdout).to match(regex)
        end

      end

      context 'autoscaling group' do

        before(:all) do
          ENV['AWS_REGION'] = @default_region
          name = @asg_config[:asg_name]
          options = {:name => name}
          @result = TestExecutor.puppet_resource('ec2_autoscalinggroup', options, '--modulepath ../')
          @asg = find_autoscaling_group(name)
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
          name = @asg_config[:lc_name]
          options = {:name => name}
          @result = TestExecutor.puppet_resource('ec2_launchconfiguration', options, '--modulepath ../')
          @lc = find_launch_config(name)
        end

        it 'security_groups' do
          response = @aws.ec2_client.describe_security_groups(group_ids: @lc.security_groups)
          names = response.data.security_groups.collect(&:group_name)
          names.each do |name|
            expect(@result.stdout).to match(/#{name}/)
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
          name = @asg_config[:policy_name]
          asg_name = @asg_config[:asg_name]
          options = {:name => name}
          @result = TestExecutor.puppet_resource('ec2_scalingpolicy', options, '--modulepath ../')
          @sp = find_scaling_policy(name, asg_name)
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

    context 'modify cloudwatch property' do

      it 'metric' do
        config = @asg_config.clone
        config[:metric] = 'NetworkIn'
        r = PuppetManifest.new(@asg_template, config).apply
        expect(r.stderr).not_to match(/error/i)
        cloudwatch = find_alarm(@asg_config[:alarm_name])
        expect(cloudwatch.metric_name).to eq('NetworkIn')
      end

      it 'namespace and metric' do

        config = @asg_config.clone
        config[:metric] = 'AWS/ELB'
        config[:namespace] = 'HealthyHostCount'
        r = PuppetManifest.new(@asg_template, config).apply
        expect(r.stderr).not_to match(/error/i)
        cloudwatch = find_alarm(@asg_config[:alarm_name])
        expect(cloudwatch.metric_name).to eq('AWS/ELB')
        expect(cloudwatch.namespace).to eq('HealthyHostCount')
      end

      it 'statistic' do
        config = @asg_config.clone
        config[:statistic] = 'Sum'
        r = PuppetManifest.new(@asg_template, config).apply
        expect(r.stderr).not_to match(/error/i)
        cloudwatch = find_alarm(@asg_config[:alarm_name])
        expect(cloudwatch.statistic).to eq('Sum')
      end

      it 'period' do
        config = @asg_config.clone
        config[:period] = 180
        r = PuppetManifest.new(@asg_template, config).apply
        expect(r.stderr).not_to match(/error/i)
        cloudwatch = find_alarm(@asg_config[:alarm_name])
        expect(cloudwatch.period).to eq(180)
      end

      it 'evaluation_periods' do
        config = @asg_config.clone
        config[:evaluation_periods] = 4
        r = PuppetManifest.new(@asg_template, config).apply
        expect(r.stderr).not_to match(/error/i)
        cloudwatch = find_alarm(@asg_config[:alarm_name])
        expect(cloudwatch.evaluation_periods).to eq(4)
      end

      it 'threshold' do
        config = @asg_config.clone
        config[:threshold] = 50
        r = PuppetManifest.new(@asg_template, config).apply
        expect(r.stderr).not_to match(/error/i)
        cloudwatch = find_alarm(@asg_config[:alarm_name])
        expect(cloudwatch.threshold).to eq(50.0)
      end

      it 'comparison_operator' do
        config = @asg_config.clone
        config[:comparison_operator] = 'GreaterThanThreshold'
        r = PuppetManifest.new(@asg_template, config).apply
        expect(r.stderr).not_to match(/error/i)
        cloudwatch = find_alarm(@asg_config[:alarm_name])
        expect(cloudwatch.comparison_operator).to eq('GreaterThanThreshold')
      end

    end

    context 'modify ec2_scalingpolicy' do

      it 'scaling_adjustment' do
        config = @asg_config.clone
        config[:scaling_adjustment] = 40
        r = PuppetManifest.new(@asg_template, config).apply
        expect(r.stderr).not_to match(/error/i)
        policy = find_scaling_policy(@asg_config[:policy_name], @asg_config[:asg_name])
        expect(policy.scaling_adjustment).to eq(40)
      end

      it 'adjustment_type' do
        config = @asg_config.clone
        config[:adjustment_type] = 'ExactCapacity'
        r = PuppetManifest.new(@asg_template, config).apply
        expect(r.stderr).not_to match(/error/i)
        policy = find_scaling_policy(@asg_config[:policy_name], @asg_config[:asg_name])
        expect(policy.adjustment_type).to eq('ExactCapacity')
      end

    end

    context 'modify ec2_autoscalinggroup' do

      it 'min_size' do
        config = @asg_config.clone
        config[:min_size] = 3
        r = PuppetManifest.new(@asg_template, config).apply
        expect(r.stderr).not_to match(/error/i)
        group = find_autoscaling_group(@asg_config[:asg_name])
        expect(group.min_size).to eq(3)
      end

      it 'max_size' do
        config = @asg_config.clone
        config[:max_size] = 5
        r = PuppetManifest.new(@asg_template, config).apply
        expect(r.stderr).not_to match(/error/i)
        group = find_autoscaling_group(@asg_config[:asg_name])
        expect(group.max_size).to eq(5)
      end

      it 'launch_configuration' do
        config = @asg_config.clone
        config[:lc_setting] = @duplicate_asg_config[:lc_name]
        r = PuppetManifest.new(@asg_template, config).apply
        expect(r.stderr).not_to match(/error/i)
        group = find_autoscaling_group(@asg_config[:asg_name])
        expect(group.launch_configuration_name).to eq(@duplicate_asg_config[:lc_name])
      end

      it 'availability_zones' do
        config = @asg_config.clone
        config[:availability_zones] = ["#{@default_region}b"]
        r = PuppetManifest.new(@asg_template, config).apply
        expect(r.stderr).not_to match(/error/i)
        group = find_autoscaling_group(@asg_config[:asg_name])
        expect(group.availability_zones.sort).to eq(config[:availability_zones].sort)
      end

    end

  end

  describe 'an autoscaling group in a VPC' do

    before(:all) do
      @template = 'autoscaling_vpc.pp.tmpl'
      @template_delete = 'autoscaling_vpc_delete.pp.tmpl'
      @config = {
        :ensure      => 'present',
        :region      => @default_region,
        :name        => "#{PuppetManifest.env_id}-#{SecureRandom.uuid}",
        :min_size    => 0,
        :max_size    => 6,
        :vpc_cidr    => '10.0.0.0/16',
        :subnet_cidr => '10.0.0.0/24',
      }
      r = PuppetManifest.new(@template, @config).apply
      expect(r.stderr).not_to match(/error/i)
    end

    after(:all) do
      @config[:ensure] = 'absent'
      r = PuppetManifest.new(@template_delete, @config).apply
      expect(r.stderr).not_to match(/error/i)
    end

    it 'should run idempotently' do
      result = PuppetManifest.new(@template, @config).apply
      expect(result.exit_code).to eq(0)
    end

    context 'should create' do
      context 'an auto scaling group' do
        it 'associated with a VPC' do
          group = find_autoscaling_group("#{@config[:name]}-asg")
          expect(group.vpc_zone_identifier).not_to be_nil
        end
      end
    end
  end

end
