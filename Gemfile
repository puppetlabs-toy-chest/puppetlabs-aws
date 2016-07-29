source ENV['GEM_SOURCE'] || 'https://rubygems.org'

def location_for(place, fake_version = nil)
  if place =~ /^(git:[^#]*)#(.*)/
    [fake_version, { :git => $1, :branch => $2, :require => false }].compact
  elsif place =~ /^file:\/\/(.*)/
    ['>= 0', { :path => File.expand_path($1), :require => false }]
  else
    [place, { :require => false }]
  end
end

gem 'aws-sdk-core', '2.3.3'
gem 'retries'

group :test do
  gem 'rake'
  gem 'puppet', *location_for(ENV['PUPPET_LOCATION'] || ENV['PUPPET_GEM_VERSION'])
  gem 'puppetlabs_spec_helper'
  gem 'webmock'
  gem 'vcr'
  gem 'rspec-puppet', :git => 'https://github.com/rodjek/rspec-puppet.git'
  gem 'metadata-json-lint'
  gem 'json_pure', '~>1.0' if RUBY_VERSION == '1.9.3'
end

group :development do
  gem 'travis'
  gem 'travis-lint'
  gem 'puppet-blacksmith'
  gem 'guard-rake'
  gem 'listen', '= 3.0.7' # last version to support ruby 1.9; the proper fix would be to not install the development group in our internal CI
  gem 'rubocop', require: false
  gem 'pry'
  gem 'librarian-puppet'
end

group :acceptance do
  gem 'mustache', '0.99.8'
  gem 'beaker-rspec'
  gem 'beaker-puppet_install_helper'
end

if File.exists? "#{__FILE__}.local"
  eval(File.read("#{__FILE__}.local"), binding)
end
