require 'spec_helper_acceptance'
require 'securerandom'

describe "ec2_autoscalinggroup" do

  before(:all) do
    @default_region = 'sa-east-1'
    @default_availability_zone = "#{@default_region}a"
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
      @lb_template = 'autoscaling_configurable_lbs.pp.tmpl'
      @lb_template_delete = 'autoscaling_configurable_lbs_delete.pp.tmpl'
      @duplicate_asg_template = 'autoscaling_duplicate.pp.tmpl'
      @dup_template_delete = 'autoscaling_duplicate_delete.pp.tmpl'
      @sg_delete = 'sg_delete.pp.tmpl'

      @lb_name = "#{name}-lb".gsub(/[^a-zA-Z0-9]/, '')[0...31] # adhere to the LB's naming restrictions

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
        :desired_capacity     => 3,
        :default_cooldown     => 400,
        :health_check_type    => 'EC2',
        :health_check_grace_period => 100,
        :new_instances_protected_from_scale_in => false,
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
        :tags                 => {
          :custom_name => "#{name}-asg",
          :department  => 'engineering',
          :project     => 'cloud',
          :created_by  => 'aws-acceptance'
        },
        :load_balancers       => [ @lb_name ],
      }
      @lb_config = {
        :name               => @lb_name,
        :ensure             => 'present',
        :region             => @default_region,
        :availability_zones => [@default_availability_zone],
        :listeners          => [
          {
            :protocol           => 'TCP',
            :load_balancer_port => 80,
            :instance_protocol  => 'TCP',
            :instance_port      => 80,
          }
        ],
        :tags => {
            :department => 'engineering',
            :project    => 'cloud',
            :created_by => 'aws-acceptance'
        }
      }
      @duplicate_asg_config = {
        :region       => @default_region,
        :sg2_name      => "#{name}-sg2",
        :lc2_name      => "#{name}-lc2",
      }
      # Mustache doesn't do nested data very well, so this creates a separate template renders for the main config and load balancers.
      # This is primarily to keep the templates and config similar to the elb_loadbalancer tests, and not have to rename everything from there.
      asg_render = PuppetManifest.new(@asg_template, @asg_config).render
      lb_render = PuppetManifest.new(@lb_template, @lb_config).render
      dup_render = PuppetManifest.new(@duplicate_asg_template, @duplicate_asg_config).render

      Aws.config[:http_wire_trace] = true
      r = PuppetRunProxy.new.apply(asg_render + "\n" + lb_render + "\n" + dup_render)

      expect(r.stderr).not_to match(/error/i)
    end

    after(:all) do
      puts "Tearing down all resources for autoscaling_spec"
      @asg_config[:ensure] = 'absent'
      @duplicate_asg_config[:ensure] = 'absent'

      asg_render = PuppetManifest.new(@asg_template_delete, @asg_config).render
      lb_render = PuppetManifest.new(@lb_template_delete, @lb_config).render
      dup_render = PuppetManifest.new(@dup_template_delete, @duplicate_asg_config).render

      puts asg_render + "\n" + lb_render + "\n" + dup_render
      r = PuppetRunProxy.new.apply(asg_render + "\n" + lb_render + "\n" + dup_render)
      expect(r.stderr).not_to match(/error/i)

      # The security group can only be deleted after lingering instances have terminated
      response = @aws.autoscaling_client.describe_auto_scaling_groups(
        auto_scaling_group_names: [@asg_config[:asg_name]],
      )
      ids = response.data[:auto_scaling_groups].first[:instances].collect { |x| x[:instance_id] }
      @aws.ec2_client.wait_until(:instance_terminated, instance_ids: ids)

      options = {
        :ensure   => 'absent',
        :name     => @asg_config[:sg_name],
        :region   => @default_region,
      }
      ENV['AWS_REGION'] = @default_region
      r2 = TestExecutor.puppet_resource('ec2_securitygroup', options, '--modulepath spec/fixtures/modules/')
      expect(r2.stderr).not_to match(/error/i)
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
          expect(@group.availability_zones).to contain_exactly('sa-east-1a', 'sa-east-1b')
          expect(@group.tags).to have_attributes(size: 4)

          custom_name_tag = @group.tags.select { |t| t.key == 'custom_name' }
          expect(custom_name_tag).to have_attributes(size: 1)
          expect(custom_name_tag.first).to have_attributes(
            key: 'custom_name',
            value: @asg_config[:asg_setting],)
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

      context 'two scaling policies' do

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
          @result = TestExecutor.puppet_resource('cloudwatch_alarm', options, '--modulepath spec/fixtures/modules/')
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
          @result = TestExecutor.puppet_resource('ec2_autoscalinggroup', options, '--modulepath spec/fixtures/modules/')
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

        it 'desired_capacity' do
          regex = /desired_capacity\s*=>\s*'#{@asg.desired_capacity}'/
          expect(@result.stdout).to match(regex)
        end

        it 'default_cooldown' do
          regex = /default_cooldown\s*=>\s*'#{@asg.default_cooldown}'/
          expect(@result.stdout).to match(regex)
        end

        it 'health_check_type' do
          regex = /health_check_type\s*=>\s*'#{@asg.health_check_type}'/
          expect(@result.stdout).to match(regex)
        end

        it 'health_check_grace_period' do
          regex = /health_check_grace_period\s*=>\s*'#{@asg.health_check_grace_period}'/
          expect(@result.stdout).to match(regex)
        end

        it 'new_instances_protected_from_scale_in' do
          regex = /health_check_grace_period\s*=>\s*'#{@asg.health_check_grace_period}'/
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

        it 'load_balancers' do
          regex = /load_balancers\s*=>\s*\[\s*'#{@lb_name}'\]/
          expect(@result.stdout).to match(regex)
        end
      end

      context 'launch_configuration' do

        before(:all) do
          ENV['AWS_REGION'] = @default_region
          name = @asg_config[:lc_name]
          options = {:name => name}
          @result = TestExecutor.puppet_resource('ec2_launchconfiguration', options, '--modulepath spec/fixtures/modules/')
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
          @result = TestExecutor.puppet_resource('ec2_scalingpolicy', options, '--modulepath spec/fixtures/modules/')
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

      it 'tags' do
        config = @asg_config.clone
        config[:tags][:other_tag] = 'tagvalue'
        r = PuppetManifest.new(@asg_template, config).apply
        expect(r.stderr).not_to match(/error/i)
        group = find_autoscaling_group(@asg_config[:asg_name])
        expect(group.tags).to have_attributes(size: 5)
        expect(group.tags.map(&:key)).to contain_exactly('custom_name', 'other_tag', 'department', 'project', 'created_by')
        expect(group.tags.map(&:value)).to contain_exactly(@asg_config[:asg_setting], 'tagvalue', 'engineering', 'cloud', 'aws-acceptance')
      end

      it 'max_size' do
        config = @asg_config.clone
        config[:max_size] = 5
        r = PuppetManifest.new(@asg_template, config).apply
        expect(r.stderr).not_to match(/error/i)
        group = find_autoscaling_group(@asg_config[:asg_name])
        expect(group.max_size).to eq(5)
      end

      it 'desired_capacity' do
        config = @asg_config.clone
        config[:desired_capacity] = 4
        r = PuppetManifest.new(@asg_template, config).apply
        expect(r.stderr).not_to match(/error/i)
        group = find_autoscaling_group(@asg_config[:asg_name])
        expect(group.desired_capacity).to eq(4)
      end

      it 'default_cooldown' do
        config = @asg_config.clone
        config[:default_cooldown] = 350
        r = PuppetManifest.new(@asg_template, config).apply
        expect(r.stderr).not_to match(/error/i)
        group = find_autoscaling_group(@asg_config[:asg_name])
        expect(group.default_cooldown).to eq(350)
      end

      it 'health_check_grace_period' do
        config = @asg_config.clone
        config[:health_check_grace_period] = 400
        r = PuppetManifest.new(@asg_template, config).apply
        expect(r.stderr).not_to match(/error/i)
        group = find_autoscaling_group(@asg_config[:asg_name])
        expect(group.health_check_grace_period).to eq(400)
      end

      it 'new_instances_protected_from_scale_in' do
        config = @asg_config.clone
        config[:new_instances_protected_from_scale_in] = true
        r = PuppetManifest.new(@asg_template, config).apply
        expect(r.stderr).not_to match(/error/i)
        group = find_autoscaling_group(@asg_config[:asg_name])
        expect(group.new_instances_protected_from_scale_in).to be true
      end

      it 'launch_configuration' do
        config = @asg_config.clone
        config[:lc_setting] = @duplicate_asg_config[:lc2_name]
        r = PuppetManifest.new(@asg_template, config).apply
        expect(r.stderr).not_to match(/error/i)
        group = find_autoscaling_group(@asg_config[:asg_name])
        expect(group.launch_configuration_name).to eq(@duplicate_asg_config[:lc2_name])
      end

      it 'availability_zones' do
        config = @asg_config.clone
        config[:availability_zones] = ["#{@default_region}b"]
        r = PuppetManifest.new(@asg_template, config).apply
        expect(r.stderr).not_to match(/error/i)
        group = find_autoscaling_group(@asg_config[:asg_name])
        expect(group.availability_zones).to contain_exactly(*config[:availability_zones])
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
