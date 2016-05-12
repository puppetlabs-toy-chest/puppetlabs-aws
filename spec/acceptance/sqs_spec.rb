require 'spec_helper_acceptance'
require 'securerandom'

describe "sqs_queue" do
  before(:all) do
    @default_region = 'us-west-1'
    @template = 'sqs_queue.pp.tmpl'
    @aws = AwsHelper.new(@default_region)
  end
  describe "should create new sqs queue" do
    before (:all) do
      @config = {
          :name => SecureRandom.hex(10),
          :ensure => 'present',
          :region => 'us-west-1',
          :delay_seconds => 100,
          :message_retention_period => 120,
          :maximum_message_size => 2048,
      }
      PuppetManifest.new(@template, @config).apply

      # Hack: queues aren't instantly visible
      # this means the ensure => absent step can get skipped
      sleep(60)
    end

    after (:all) do
      new_config = @config.update({
                                      :ensure => 'absent',
                                      :region => 'us-west-1'
                                  })
      PuppetManifest.new(@template, new_config).apply
    end

    it "creates a queue and which has a url" do
      url = @aws.get_sqs_queue_url(@config[:name])
      expect(url).to include("amazonaws.com/")
    end

    it "has expected retention_period" do
      url = @aws.get_sqs_queue_url(@config[:name])
      attrs = @aws.get_sqs_queue_attributes(url)
      expect(attrs["MessageRetentionPeriod"]).to eq(@config[:message_retention_period].to_s)
    end

    it "has expected delay seconds" do
      url = @aws.get_sqs_queue_url(@config[:name])
      attrs = @aws.get_sqs_queue_attributes(url)
      expect(attrs["DelaySeconds"]).to eq(@config[:delay_seconds].to_s)
    end

    it "has expected maximum message size" do
      url = @aws.get_sqs_queue_url(@config[:name])
      attrs = @aws.get_sqs_queue_attributes(url)
      expect(attrs["MaximumMessageSize"]).to eq(@config[:maximum_message_size].to_s)
    end

    context "using resource" do
      before(:all) do
        ENV['AWS_REGION'] = @default_region
        options = {:name => @config[:name]}
        @result = TestExecutor.puppet_resource('sqs_queue', options, '--modulepath spec/fixtures/modules/')
      end

      it 'should show the queue as present' do
        regex = /ensure\s*=>\s*'present'/
        expect(@result.stdout).to match(regex)
      end

      it 'should show delay seconds' do
        regex = /delay_seconds\s*=>\s*'100'/
        expect(@result.stdout).to match(regex)
      end

      it 'should show message_retention_period ' do
        regex = /message_retention_period\s*=>\s*'120'/
        expect(@result.stdout).to match(regex)
      end
      it 'should show maximum_message_size' do
        regex = /maximum_message_size\s*=>\s*'2048'/
        expect(@result.stdout).to match(regex)
      end
    end


    context "change params" do
      before (:all) do
        new_config = @config.update({
                                        :delay_seconds => 200,
                                        :message_retention_period => 140,
                                        :maximum_message_size => 4048,
                                    })
        PuppetManifest.new(@template, new_config).apply
        sleep(60)
      end

      it "updates expected_queue_size" do
        url = @aws.get_sqs_queue_url(@config[:name])
        attrs = @aws.get_sqs_queue_attributes(url)
        expect(attrs["MaximumMessageSize"]).to eq(@config[:maximum_message_size].to_s)
      end

      it "updates expected message_retention_period" do
        url = @aws.get_sqs_queue_url(@config[:name])
        attrs = @aws.get_sqs_queue_attributes(url)
        expect(attrs["MessageRetentionPeriod"]).to eq(@config[:message_retention_period].to_s)
      end

      it "update delay seconds " do
        url = @aws.get_sqs_queue_url(@config[:name])
        attrs = @aws.get_sqs_queue_attributes(url)
        expect(attrs["DelaySeconds"]).to eq(@config[:delay_seconds].to_s)
      end
    end
  end
end

