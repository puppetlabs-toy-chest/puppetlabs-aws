require 'spec_helper_acceptance'
require 'securerandom'

describe "route53_zone" do

  before(:all) do
    @default_region = 'sa-east-1'
    @aws = AwsHelper.new(@default_region)
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

  describe 'should create a new zone and some DNS record' do

    before(:all) do
      @name = "#{SecureRandom.uuid}.com."
      @config = {
        :name => @name,
        :a_record_name => "local.#{@name}",
        :a_ttl => 3000,
        :a_values => ['127.0.0.1'],
        :txt_record_name => "local.#{@name}",
        :txt_ttl => 17000,
        :txt_value => 'message',
      }

      @template = 'route53_create.pp.tmpl'
      PuppetManifest.new(@template, @config).apply
      @zone = find_zone(@name)
      @a_record = find_record(@config[:a_record_name], @zone, 'A')
      @ns_record = find_record(@config[:name], @zone, 'NS')
      @soa_record = find_record(@config[:name], @zone, 'SOA')
      @txt_record = find_record(@config[:txt_record_name], @zone, 'TXT')
    end

    after(:all) do
      template = 'route53_delete.pp.tmpl'
      PuppetManifest.new(template, @config).apply
      expect(@aws.get_dns_zones(@name)).to be_empty
    end

    it 'should run idempotently' do
      success = PuppetManifest.new(@template, @config).apply[:exit_status].success?
      expect(success).to eq(true)
    end

    it 'should create a DNS zone with the correct name' do
      expect(@zone.name).to eq(@name)
    end

    it 'should automatically create an NS record for the zone' do
      expect(@ns_record).not_to be_nil
    end

    it 'should automatically create an SOA record for the zone' do
      expect(@soa_record).not_to be_nil
    end

    it 'should create an A record with the relevant ttl' do
      expect(@a_record.ttl).to eq(@config[:a_ttl])
    end

    it 'should create an A record with the relevant values' do
      expect(@a_record.resource_records.map(&:value)).to eq(@config[:a_values])
    end

    describe 'using puppet resource on the A record' do
      before(:all) do
        ENV['AWS_REGION'] = @default_region
        options = {:name => @config[:a_record_name]}
        @result = TestExecutor.puppet_resource('route53_a_record', options, '--modulepath ../')
      end

      it 'should show the correct TTL' do
        regex = /ttl\s*=>\s*'#{@config[:a_ttl]}'/
        expect(@result.stdout).to match(regex)
      end

      it 'should show the correct zone' do
        regex = /zone\s*=>\s*'#{@config[:name]}'/
        expect(@result.stdout).to match(regex)
      end

      it 'should show the correct values' do
        regex = /values\s*=>\s*#{@config[:a_values]}/
        expect(@result.stdout).to match(regex)
      end
    end

    describe 'using puppet resource on the TXT record' do
      before(:all) do
        ENV['AWS_REGION'] = @default_region
        options = {:name => @config[:txt_record_name]}
        @result = TestExecutor.puppet_resource('route53_txt_record', options, '--modulepath ../')
      end

      it 'should show the correct TTL' do
        regex = /ttl\s*=>\s*'#{@config[:txt_ttl]}'/
        expect(@result.stdout).to match(regex)
      end

      it 'should show the correct zone' do
        regex = /zone\s*=>\s*'#{@config[:name]}'/
        expect(@result.stdout).to match(regex)
      end
    end

    describe 'using puppet resource on the auto generted NS record' do
      before(:all) do
        ENV['AWS_REGION'] = @default_region
        options = {:name => @config[:name]}
        @result = TestExecutor.puppet_resource('route53_ns_record', options, '--modulepath ../')
      end

      it 'should show the correct zone' do
        regex = /zone\s*=>\s*'#{@config[:name]}'/
        expect(@result.stdout).to match(regex)
      end
    end

    it 'should create an TXT record with the relevant ttl' do
      expect(@txt_record.ttl).to eq(@config[:txt_ttl])
    end

    it 'should create an TXT record with the relevant value' do
      expect(@txt_record.resource_records.map(&:value)).to eq(["\"message\""])
    end

    it 'should allow the ttl to be changed on the A record' do
      new_config = @config.update({:a_ttl => 4000})
      PuppetManifest.new(@template, new_config).apply
      record = find_record(@config[:a_record_name], @zone, 'A')
      expect(record.ttl).to eq(new_config[:a_ttl])
    end

    it 'should allow the value to be changed on the A record' do
      new_config = @config.update({:a_values => ['127.0.0.2', '127.0.0.3']})
      PuppetManifest.new(@template, new_config).apply
      record = find_record(@config[:a_record_name], @zone, 'A')
      expect(record.resource_records.map(&:value)).to eq(new_config[:a_values])
    end
  end

  describe 'create new zone' do

    before(:all) do
      @template = 'route53_with_ns_create.pp.tmpl'
      @name = "#{SecureRandom.uuid}.com."
      @config = {
        :name             => @name,
        :a_record_name    => "local.#{@name}",
        :a_ttl            => 3000,
        :a_values         => ['127.0.0.1', '127.0.0.2', '127.0.0.3'],
        :txt_record_name  => "local.#{@name}",
        :txt_ttl          => 4000,
        :txt_values       => ['This is a test', 'Test all the things!', 'Very wow much test'],
        :ns_record_name   => "local.#{@name}",
        :ns_ttl           => 6000,
        :ns_values         => ['ns1.example.com','ns2.example.com','ns3.example.com'],
      }
      PuppetManifest.new(@template, @config).apply
      @zone = find_zone(@name)
    end

    after(:all) do
      template = 'route53_with_ns_delete.pp.tmpl'
      PuppetManifest.new(template, @config).apply
      expect(@aws.get_dns_zones(@name)).to be_empty
    end

    context 'mutate the properties' do

      context 'ns record' do

        it 'ttl' do
          config = @config.clone
          config[:ns_ttl] = 4000
          r = PuppetManifest.new(@template, config).apply
          expect(r[:output].any?{|x| x.include? 'Error'}).to eq(false)
          record = find_record(config[:ns_record_name], @zone, 'NS')
          expect(record.ttl).to eq(config[:ns_ttl])
        end

        it 'value' do
          config = @config.clone
          config[:ns_values] = ['ns1.example.com', 'ns5.example.com', 'ns3.example.com']
          r = PuppetManifest.new(@template, config).apply
          expect(r[:output].any?{|x| x.include? 'Error'}).to eq(false)
          record = find_record(config[:ns_record_name], @zone, 'NS')
          expect(record.resource_records.map(&:values).flatten).to eq(config[:ns_values])
        end

      end

      context 'txt record' do

        it 'ttl' do
          config = @config.clone
          config[:txt_ttl] = 7000
          r = PuppetManifest.new(@template, config).apply
          expect(r[:output].any?{|x| x.include? 'Error'}).to eq(false)
          record = find_record(config[:txt_record_name], @zone, 'TXT')
          expect(record.ttl).to eq(config[:txt_ttl])
        end

        it 'value' do
          config = @config.clone
          config[:txt_values] = ['This is a test', 'Test all the other things!', 'Very wow much test']
          r = PuppetManifest.new(@template, config).apply
          expect(r[:output].any?{|x| x.include? 'Error'}).to eq(false)
          record = find_record(config[:txt_record_name], @zone, 'TXT')
          expect(record.resource_records.map{|x| x.value.delete('/"')}).to eq(config[:txt_values])
        end

      end

    end

  end

end
