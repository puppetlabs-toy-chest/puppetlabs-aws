require 'spec_helper_acceptance'
require 'securerandom'

describe "route53_zone" do

  before(:all) do
    @default_region = 'sa-east-1'
    @aws = Ec2Helper.new(@default_region)
  end

  def find_zone(name)
    zones = @aws.get_dns_zones(name)
    expect(zones.count).to eq(1)
    zones.first
  end

  def find_record(name, zone, type)
    records = @aws.get_dns_records(name, zone, type)
    expect(records.count).to eq(1)
    records.first
  end


  describe 'should create a new zone and A record' do

    before(:all) do
      @name = "#{SecureRandom.uuid}.com."
      @config = {
        :name => @name,
        :record_name => "local.#{@name}",
        :ttl => 3000,
        :values => ['127.0.0.1'],
      }

      @template = 'route53_create.pp.tmpl'
      PuppetManifest.new(@template, @config).apply
      @zone = find_zone(@name)
      @record = find_record(@config[:record_name], @zone, 'A')
    end

    after(:all) do
      template = 'route53_delete.pp.tmpl'
      PuppetManifest.new(template, @config).apply
      expect(@aws.get_dns_zones(@name)).to be_empty
    end

    it 'should create a DNS zone with the correct name' do
      expect(@zone.name).to eq(@name)
    end

    it 'should create an A record with the relevant ttl' do
      expect(@record.ttl).to eq(@config[:ttl])
    end

    it 'should create an A record with the relevant values' do
      expect(@record.resource_records.map(&:value)).to eq(@config[:values])
    end

    it 'should allow the ttl to be changed' do
      new_config = @config.update({:ttl => 4000})
      PuppetManifest.new(@template, new_config).apply
      record = find_record(@config[:record_name], @zone, 'A')
      expect(record.ttl).to eq(new_config[:ttl])
    end

    it 'should allow the value to be changed' do
      new_config = @config.update({:values => ['127.0.0.2', '127.0.0.3']})
      PuppetManifest.new(@template, new_config).apply
      record = find_record(@config[:record_name], @zone, 'A')
      expect(record.resource_records.map(&:value)).to eq(new_config[:values])
    end

  end

end
