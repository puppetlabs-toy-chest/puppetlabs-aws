require 'puppetlabs_spec_helper/rake_tasks'

begin
  require 'puppet_blacksmith/rake_tasks'
rescue LoadError
end

begin
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new
rescue LoadError
end

require 'puppet-lint/tasks/puppet-lint'
PuppetLint.configuration.ignore_paths = ["contrib/**/*.pp", "tests/**/*.pp", "spec/**/*.pp", "pkg/**/*.pp"]
