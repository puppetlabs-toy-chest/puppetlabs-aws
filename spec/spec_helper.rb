require 'aws-sdk-core'
require 'puppetlabs_spec_helper/module_spec_helper'
require 'webmock/rspec'
require 'vcr'

WebMock.disable_net_connect!

VCR.configure do |c|
  c.cassette_library_dir = 'fixtures/vcr_cassettes'
  c.hook_into :webmock
  c.allow_http_connections_when_no_cassette = true
end
