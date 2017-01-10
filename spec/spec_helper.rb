require 'aws-sdk-core'
require 'puppetlabs_spec_helper/module_spec_helper'
require 'webmock/rspec'
require 'vcr'

WebMock.disable_net_connect!

unless ENV['AWS_ACCESS_KEY_ID']
  ENV['AWS_ACCESS_KEY_ID'] = 'redacted'
end

unless ENV['AWS_SECRET_ACCESS_KEY']
  ENV['AWS_SECRET_ACCESS_KEY'] = 'redacted'
end

unless ENV['AWS_REGION']
  ENV['AWS_REGION'] = 'sa-east-1'
end

VCR.configure do |c|
  c.cassette_library_dir = 'fixtures/vcr_cassettes'
  c.hook_into :webmock
  c.filter_sensitive_data('111111111111') { ENV['AWS_ACCESS_KEY_ID'] }

  # Filter the account number from arn references
  c.filter_sensitive_data('123456789012') {|i|
    # arn:aws:component:region:account:otherstuff
    if matches = /arn:aws:\w+:([\-\w]+)?:(\d{12}):/.match(i.response.body)
      matches[2]
    end
  }

  # Filter account from ELB Data
  c.filter_sensitive_data('123456789012') {|i|
    if matches = /<OwnerAlias>(\d{12})<\/OwnerAlias>/.match(i.response.body)
      matches[1]
    elsif matches = /<ownerId>(\d{12})<\/ownerId>/.match(i.response.body)
      matches[1]
    end
  }

end

if ENV['PARSER'] == 'future'
  RSpec.configure do |c|
    c.parser = 'future'
  end
end

RSpec::Matchers.define :order_tags_on_output do |expected|
  match do |actual|
    tags = {'b' => 1, 'a' => 2}
    reverse = {'a' => 2, 'b' => 1}
    srv = actual.new(:name => 'sample', :tags => tags )
    expect(srv.property(:tags).insync?(tags)).to be true
    expect(srv.property(:tags).insync?(reverse)).to be true
    expect(srv.property(:tags).should_to_s(tags).to_s).to eq(reverse.to_s)
  end
  failure_message do |actual|
    "expected that #{actual} would order tags"
  end
end

RSpec::Matchers.define :require_string_for do |property|
  match do |type_class|
    config = {name: 'name'}
    config[property] = 2
    expect {
      type_class.new(config)
    }.to raise_error(Puppet::Error, /#{property} should be a String/)
  end
  failure_message do |type_class|
    "#{type_class} should require #{property} to be a String"
  end
end

RSpec::Matchers.define :require_hash_for do |property|
  match do |type_class|
    config = {name: 'name'}
    config[property] = 2
    expect {
      type_class.new(config)
    }.to raise_error(Puppet::Error, /#{property} should be a Hash/)
  end
  failure_message do |type_class|
    "#{type_class} should require #{property} to be a Hash"
  end
end
