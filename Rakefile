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

ignore_paths = ['contrib/**/*.pp', 'examples/**/*.pp', 'spec/**/*.pp', 'pkg/**/*.pp', 'vendor/**/*']

# necessary to ensure default :lint doesn't exist, else ignore_paths won't work
Rake::Task[:lint].clear

PuppetLint.configuration.relative = true
PuppetLint.configuration.disable_class_inherits_from_params_class
PuppetLint::RakeTask.new :lint do |config|
  config.ignore_paths = ignore_paths
end

PuppetSyntax.exclude_paths = ignore_paths


jenkins_tests = [
  'spec/*/vpc_spec.rb',
  'spec/*/negative_vpc_spec.rb'
]

desc "Run jenkins tests"
RSpec::Core::RakeTask.new(:jenkins => [:spec_prep]) do |t|
  t.pattern = jenkins_tests
end

desc "Run full acceptance tests"
RSpec::Core::RakeTask.new(:full => [:spec_prep]) do |t|
  t.pattern = 'spec/acceptance'
end

task :metadata do
  sh "bundle exec metadata-json-lint metadata.json"
end

desc "Run lint and spec tests and check metadata format"
task :test => [
  :syntax,
  :lint,
  :spec,
  :metadata,
]
