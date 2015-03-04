require 'aws-sdk-core'
require 'puppetlabs_spec_helper/module_spec_helper'
require 'webmock/rspec'
require 'vcr'

WebMock.disable_net_connect!

VCR.configure do |c|
  c.cassette_library_dir = 'fixtures/vcr_cassettes'
  c.hook_into :webmock
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
  failure_message_for_should do |actual|
    "expected that #{actual} would order tags"
  end
end
