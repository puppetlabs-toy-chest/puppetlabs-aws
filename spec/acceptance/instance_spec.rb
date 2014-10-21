require 'securerandom'
require 'open3'
require 'aws-sdk-core'

def run_puppet(code)
  run = code.strip.gsub("\n", '')
  `bundle exec puppet apply -e "#{run}" --test --modulepath ../`
end

describe "ec2_instance" do

  before(:all) do

    seed = SecureRandom.uuid
    @name = "#{seed}-instance"
    @type = 't1.micro'
    @region = 'sa-east-1'
    @ami = 'ami-41e85d5c'

    code_under_test = <<-EOS
      ec2_instance { '#{@name}':
        ensure => present,
        region => '#{@region}',
        image_id => '#{@ami}',
        instance_type => '#{@type}',
        security_groups => ['default'],
      }
    EOS

    run_puppet(code_under_test)

  end

  after(:all) do

    code_under_test = <<-EOS
      ec2_instance { '#{@name}':
        ensure => absent,
        region => '#{@region}',
      }
    EOS

    run_puppet(code_under_test)

  end

  describe 'should create a new instance' do

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
