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

# necessary to ensure default :lint doesn't exist, else ignore_paths won't work
Rake::Task[:lint].clear

PuppetLint.configuration.relative = true
PuppetLint.configuration.disable_class_inherits_from_params_class
PuppetLint::RakeTask.new :lint do |config|
  config.ignore_paths = ['contrib/**/*.pp', 'tests/**/*.pp', 'spec/**/*.pp', 'pkg/**/*.pp']
end

desc "Run acceptance tests"
RSpec::Core::RakeTask.new(:acceptance) do |t|
    t.pattern = 'spec/acceptance'
end
