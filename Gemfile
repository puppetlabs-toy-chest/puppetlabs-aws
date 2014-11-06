source 'https://rubygems.org'

def location_for(place, fake_version = nil)
  if place =~ /^(git:[^#]*)#(.*)/
    [fake_version, { :git => $1, :branch => $2, :require => false }].compact
  elsif place =~ /^file:\/\/(.*)/
    ['>= 0', { :path => File.expand_path($1), :require => false }]
  else
    [place, { :require => false }]
  end
end

gem 'aws-sdk-core', '2.0.5'

group :test do
  gem 'rake'
  gem "puppet", *location_for(ENV['PUPPET_LOCATION'] || '~> 3.7.0')
  gem 'puppetlabs_spec_helper'
  gem 'webmock'
  gem 'vcr'
  gem 'rspec-puppet', :git => 'https://github.com/rodjek/rspec-puppet.git'
  gem "mustache"
end

group :development do
  gem 'travis'
  gem 'travis-lint'
  gem 'puppet-blacksmith'
  gem 'guard-rake'
  gem 'rubocop', require: false
  gem 'pry'
  gem 'pry-byebug'
  gem 'librarian-puppet'
  gem 'clamp'
  gem "hiera-eyaml"
end

if File.exists? "#{__FILE__}.local"
  eval(File.read("#{__FILE__}.local"), binding)
end
