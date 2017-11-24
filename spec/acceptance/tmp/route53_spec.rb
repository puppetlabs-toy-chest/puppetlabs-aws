require 'spec_helper_acceptance'
require 'securerandom'

describe "route53_zone" do
  before(:all) do
    skip("Disabled pending fix for https://github.com/puppetlabs/puppetlabs-aws/issues/451")
  end

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
        :spf_record_name => "local.#{@name}",
        :spf_ttl => 300,
        :spf_value => 'v=spf1 a -all',
        :cname_record_name => "local2.#{@name}",
        :cname_ttl => 304,
        :cname_values => ["local3.#{@name}"],
        :mx_record_name => "local.#{@name}",
        :mx_ttl => 303,
        :mx_values => ["10 mail.local.#{@name}", "20 mail.local.#{@name}"],
        :aaaa_record_name => "local.#{@name}",
        :aaaa_ttl => 302,
        :aaaa_values => ['2001:0db8:85a3:0:0:8a2e:0370:7334'],
        :srv_record_name => "local.#{@name}",
        :srv_ttl => 301,
        :srv_values => ["1 10 5269 xmpp-server.#{@name}",  "2 12 5060 sip-server.#{@name}"],
      }

      @template = 'route53_create.pp.tmpl'
      PuppetManifest.new(@template, @config).apply
      @zone = find_zone(@name)
      @a_record = find_record(@config[:a_record_name], @zone, 'A')
      @ns_record = find_record(@config[:name], @zone, 'NS')
      @soa_record = find_record(@config[:name], @zone, 'SOA')
      @txt_record = find_record(@config[:txt_record_name], @zone, 'TXT')
      @spf_record = find_record(@config[:spf_record_name], @zone, 'SPF')
      @cname_record = find_record(@config[:cname_record_name], @zone, 'CNAME')
      @mx_record = find_record(@config[:mx_record_name], @zone, 'MX')
      @aaaa_record = find_record(@config[:aaaa_record_name], @zone, 'AAAA')
      @srv_record = find_record(@config[:srv_record_name], @zone, 'SRV')
    end

    after(:all) do
      template = 'route53_delete.pp.tmpl'
      PuppetManifest.new(template, @config).apply
      expect(@aws.get_dns_zones(@name)).to be_empty
    end

    it 'should run idempotently' do
      result = PuppetManifest.new(@template, @config).apply
      expect(result.exit_code).to eq(0)
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
        @result = TestExecutor.puppet_resource('route53_a_record', options, '--modulepath spec/fixtures/modules/')
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

    it 'should create an MX record with the relevant ttl' do
      expect(@mx_record.ttl).to eq(@config[:mx_ttl])
    end

    it 'should create an MX record with the relevant values' do
      expect(@mx_record.resource_records.map(&:value)).to eq(@config[:mx_values])
    end

    describe 'using puppet resource on the MX record' do
      before(:all) do
        ENV['AWS_REGION'] = @default_region
        options = {:name => @config[:mx_record_name]}
        @result = TestExecutor.puppet_resource('route53_mx_record', options, '--modulepath spec/fixtures/modules/')
      end

      it 'should show the correct TTL' do
        regex = /ttl\s*=>\s*'#{@config[:mx_ttl]}'/
        expect(@result.stdout).to match(regex)
      end

      it 'should show the correct zone' do
        regex = /zone\s*=>\s*'#{@config[:name]}'/
        expect(@result.stdout).to match(regex)
      end

      it 'should show the correct values' do
        regex = /values\s*=>\s*\['#{@config[:mx_values].first}', '#{@config[:mx_values][1]}'\]/
        expect(@result.stdout).to match(regex)
      end
    end

    it 'should create a CNAME record with the relevant ttl' do
      expect(@cname_record.ttl).to eq(@config[:cname_ttl])
    end

    it 'should create a CNAME record with the relevant values' do
      expect(@cname_record.resource_records.map(&:value)).to eq(@config[:cname_values])
    end

    describe 'using puppet resource on the CNAME record' do
      before(:all) do
        ENV['AWS_REGION'] = @default_region
        options = {:name => @config[:cname_record_name]}
        @result = TestExecutor.puppet_resource('route53_cname_record', options, '--modulepath spec/fixtures/modules/')
      end

      it 'should show the correct TTL' do
        regex = /ttl\s*=>\s*'#{@config[:cname_ttl]}'/
        expect(@result.stdout).to match(regex)
      end

      it 'should show the correct zone' do
        regex = /zone\s*=>\s*'#{@config[:name]}'/
        expect(@result.stdout).to match(regex)
      end

      it 'should show the correct values' do
        regex = /values\s*=>\s*\['#{@config[:cname_values].first}'\]/
        expect(@result.stdout).to match(regex)
      end
    end

    it 'should create an SRV record with the relevant ttl' do
      expect(@srv_record.ttl).to eq(@config[:srv_ttl])
    end

    it 'should create an SRV record with the relevant values' do
      expect(@srv_record.resource_records.map(&:value)).to eq(@config[:srv_values])
    end

    describe 'using puppet resource on the SRV record' do
      before(:all) do
        ENV['AWS_REGION'] = @default_region
        options = {:name => @config[:srv_record_name]}
        @result = TestExecutor.puppet_resource('route53_srv_record', options, '--modulepath spec/fixtures/modules/')
      end

      it 'should show the correct TTL' do
        regex = /ttl\s*=>\s*'#{@config[:srv_ttl]}'/
        expect(@result.stdout).to match(regex)
      end

      it 'should show the correct zone' do
        regex = /zone\s*=>\s*'#{@config[:name]}'/
        expect(@result.stdout).to match(regex)
      end

    end

    it 'should create an AAAA record with the relevant ttl' do
      expect(@aaaa_record.ttl).to eq(@config[:aaaa_ttl])
    end

    it 'should create an AAAA record with the relevant values' do
      expect(@aaaa_record.resource_records.map(&:value)).to eq(@config[:aaaa_values])
    end

    describe 'using puppet resource on the AAAA record' do
      before(:all) do
        ENV['AWS_REGION'] = @default_region
        options = {:name => @config[:aaaa_record_name]}
        @result = TestExecutor.puppet_resource('route53_aaaa_record', options, '--modulepath spec/fixtures/modules/')
      end

      it 'should show the correct TTL' do
        regex = /ttl\s*=>\s*'#{@config[:aaaa_ttl]}'/
        expect(@result.stdout).to match(regex)
      end

      it 'should show the correct zone' do
        regex = /zone\s*=>\s*'#{@config[:name]}'/
        expect(@result.stdout).to match(regex)
      end

      it 'should show the correct values' do
        regex = /values\s*=>\s*\['#{@config[:aaaa_values].first}'\]/
        expect(@result.stdout).to match(regex)
      end
    end

    describe 'using puppet resource on the TXT record' do
      before(:all) do
        ENV['AWS_REGION'] = @default_region
        options = {:name => @config[:txt_record_name]}
        @result = TestExecutor.puppet_resource('route53_txt_record', options, '--modulepath spec/fixtures/modules/')
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

    it 'should create an SPF record with the relevant ttl' do
      expect(@spf_record.ttl).to eq(@config[:spf_ttl])
    end

    it 'should create an SPF record with the relevant values' do
      expect(@spf_record.resource_records.map(&:value)).to eq(["\"v=spf1 a -all\""])
    end

    describe 'using puppet resource on the SPF record' do
      before(:all) do
        ENV['AWS_REGION'] = @default_region
        options = {:name => @config[:spf_record_name]}
        @result = TestExecutor.puppet_resource('route53_spf_record', options, '--modulepath spec/fixtures/modules/')
      end

      it 'should show the correct TTL' do
        regex = /ttl\s*=>\s*'#{@config[:spf_ttl]}'/
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
        @result = TestExecutor.puppet_resource('route53_ns_record', options, '--modulepath spec/fixtures/modules/')
      end

      it 'should show the correct zone' do
        regex = /zone\s*=>\s*'#{@config[:name]}'/
        expect(@result.stdout).to match(regex)
      end
    end

    describe 'using puppet resource on the route53_zone' do
      before(:all) do
        ENV['AWS_REGION'] = @default_region
        options = {:name => @config[:name]}
        @result = TestExecutor.puppet_resource('route53_zone', options, '--modulepath spec/fixtures/modules/')
      end

      it 'should show the zone as present' do
        regex = /ensure\s*=>\s*'present'/
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
      expect(record.resource_records.map(&:value).to_set).to eq(new_config[:a_values].to_set)
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
          expect(r.stderr).not_to match(/error/i)
          record = find_record(config[:ns_record_name], @zone, 'NS')
          expect(record.ttl).to eq(config[:ns_ttl])
        end

        it 'value' do
          config = @config.clone
          config[:ns_values] = ['ns1.example.com', 'ns5.example.com', 'ns3.example.com']
          r = PuppetManifest.new(@template, config).apply
          expect(r.stderr).not_to match(/error/i)
          record = find_record(config[:ns_record_name], @zone, 'NS')
          expect(record.resource_records.map(&:values).flatten.to_set).to eq(config[:ns_values].to_set)
        end

      end

      context 'txt record' do

        it 'ttl' do
          config = @config.clone
          config[:txt_ttl] = 7000
          r = PuppetManifest.new(@template, config).apply
          expect(r.stderr).not_to match(/error/i)
          record = find_record(config[:txt_record_name], @zone, 'TXT')
          expect(record.ttl).to eq(config[:txt_ttl])
        end

        it 'value' do
          config = @config.clone
          config[:txt_values] = ['This is a test', 'Test all the other things!', 'Very wow much test']
          r = PuppetManifest.new(@template, config).apply
          expect(r.stderr).not_to match(/error/i)
          record = find_record(config[:txt_record_name], @zone, 'TXT')
          expect(record.resource_records.map{|x| x.value.delete('/"')}.to_set).to eq(config[:txt_values].to_set)
        end
      end
    end
  end

  describe 'create route53 zone' do

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
      @template = 'route53_create_minimal.pp.tmpl'
    end

    it 'with puppet resource' do
      options = {:name => @config[:name], :ensure => 'present'}
      result = TestExecutor.puppet_resource('route53_zone', options, '--modulepath spec/fixtures/modules/')
      expect(result.stderr).not_to match(/Error:/)
      expect{ find_zone(@config[:name]) }.not_to raise_error
    end

    it 'add records to the zone with a manifest' do
      result = PuppetManifest.new(@template, @config).apply
      expect(result.stderr).not_to match(/error/i)
      zone = find_zone(@config[:name])
      expect{find_record(@config[:txt_record_name], zone, 'TXT')}.not_to raise_error
      expect{find_record(@config[:a_record_name], zone, 'A')}.not_to raise_error
    end

    context 'deleting resources' do

      it 'attempt to delete the zone first' do
        options = {:name => @config[:name], :ensure => 'absent'}
        result = TestExecutor.puppet_resource('route53_zone', options, '--modulepath spec/fixtures/modules/')
        regex = /Could not set 'absent' on ensure/
        expect(result.stderr).to match(regex)
      end

      it 'a_record' do
        options = {:name => @config[:a_record_name], :ensure => 'absent'}
        result = TestExecutor.puppet_resource('route53_a_record', options, '--modulepath spec/fixtures/modules/')
        expect(result.stderr).not_to match(/Error:/)
        zone = find_zone(@config[:name])
        expect{ find_record(@config[:a_record_name], zone, 'A')}.to raise_error
      end

      it 'txt_record' do
        options = {:name => @config[:txt_record_name], :ensure => 'absent'}
        result = TestExecutor.puppet_resource('route53_txt_record', options, '--modulepath spec/fixtures/modules/')
        expect(result.stderr).not_to match(/Error:/)
        zone = find_zone(@config[:name])
        expect{ find_record(@config[:txt_record_name], zone, 'TXT')}.to raise_error
      end

      it 'route53_zone' do
        options = {:name => @config[:name], :ensure => 'absent'}
        result = TestExecutor.puppet_resource('route53_zone', options, '--modulepath spec/fixtures/modules/')
        expect(result.stderr).not_to match(/Error:/)
        expect{ find_zone(@config[:name])}.to raise_error
      end

    end

  end

end
