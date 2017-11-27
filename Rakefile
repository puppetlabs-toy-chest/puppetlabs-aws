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
  'spec/*/negative_vpc_spec.rb',
  'spec/*/cleanup_spec.rb'
]

scaling_tests = [
  'spec/*/autoscaling_spec.rb',
  'spec/*/loadbalancer_spec.rb',
  'spec/*/cleanup_spec.rb'
]

rds_tests = [
  'spec/*/rds_db_securitygroup_spec.rb',
  'spec/*/rds_spec.rb',
  'spec/*/sqs_spec.rb'
]

full_tests = [
  'spec/*/all_properties_vpc_spec.rb',
  'spec/*/instance_spec.rb',
  'spec/*/securitygroup_spec.rb',
  'spec/*/vpc_puppet_resource_spec.rb',
  'spec/*/cleanup_spec.rb'
]


desc "Run scaling tests"
RSpec::Core::RakeTask.new(:scale => [:spec_prep]) do |t|
  t.pattern = scaling_tests
end

desc "Run rds tests"
RSpec::Core::RakeTask.new(:rds => [:spec_prep]) do |t|
  t.pattern = rds_tests
end

desc "Run full acceptance tests"
RSpec::Core::RakeTask.new(:jenkins => [:spec_prep, :rds, :scale]) do |t|
  t.pattern = full_tests
end

desc "Run jenkins acceptance tests"
RSpec::Core::RakeTask.new(:acceptance => [:spec_prep]) do |t|
  t.pattern = jenkins_tests
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
