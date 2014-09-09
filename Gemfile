source 'https://rubygems.org'

gem 'retries'
gem 'aws-sdk-core', '~> 2.0.0.rc'

group :test do
  gem 'rake'
  gem 'puppet', ENV['PUPPET_VERSION'] || '~> 3.7.0'
  gem 'puppetlabs_spec_helper'
  gem 'webmock'
  gem 'vcr'
end

group :development do
  gem 'travis'
  gem 'travis-lint'
  gem 'puppet-blacksmith'
  gem 'guard-rake'
  gem 'rubocop', require: false
  gem 'pry'
end
