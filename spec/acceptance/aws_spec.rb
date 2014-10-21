require 'spec_helper_acceptance'
require 'aws-sdk-core'

describe 'ec2_instance' do

  before(:all) do
    seed = SecureRandom.uuid
    @name = "#{seed}-instance"
    @type = 't1.micro'
    @region = 'sa-east-1'
    @ami = 'ami-41e85d5c'
  end

  after(:all) do
    pp = <<-EOS
      ec2_instance { '#{@name}':
        ensure => absent,
        region => '#{@region}',
      }
    EOS
    apply_manifest(pp, :catch_failures => true)
  end

  context 'with minimal parameters' do
    it 'should apply idempotently' do
      pp = <<-EOS
        ec2_instance { '#{@name}':
          ensure => present,
          region => '#{@region}',
          image_id => '#{@ami}',
          instance_type => '#{@type}',
          security_groups => ['default']
        }
      EOS

      apply_manifest(pp, :catch_failures => true)
      apply_manifest(pp, :catch_changes => true)
    end

    describe package('aws-sdk-core') do
      it { should be_installed.by('gem') }
    end

    describe 'should create a new instance in AWS' do

      before(:all) do
        client = ::Aws::EC2::Client.new({region: @region})
        response = client.describe_instances(filters: [
          {name: 'tag:Name', values: [@name]},
        ])
        instances = response.data.reservations.collect do |reservation|
          reservation.instances.collect do |instance|
            instance
          end
        end.flatten
        expect(instances.count).to eq(1)
        @instance = instances.first
      end

      it "with the specified name" do
        expect(@instance.tags.detect { |tag| tag.key == 'Name' }.value).to eq(@name)
      end

      it "with the specified type" do
        expect(@instance.instance_type).to eq(@type)
      end

      it "with the specified AMI" do
        expect(@instance.image_id).to eq(@ami)
      end

    end

  end
end
