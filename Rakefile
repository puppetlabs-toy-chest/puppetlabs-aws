require 'puppetlabs_spec_helper/rake_tasks'
require 'puppet/vendor/semantic/lib/semantic'

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

desc "Run acceptance tests"
RSpec::Core::RakeTask.new(:acceptance) do |t|
    t.pattern = 'spec/acceptance'
end

desc "Run integration tests"
RSpec::Core::RakeTask.new(:integration) do |t|
  t.pattern = 'spec/acceptance/integration'
  ENV['BEAKER_setfile'] ||= 'spec/acceptance/beaker/nodesets/rhel7.yaml'
  ENV['SPEC_FORGE'] ||= 'https://api-forge-aio01-qatest.puppetlabs.com/'
  unless ENV['SPEC_VERSION']
    raise StandardError 'You must specify the environment variable SPEC_VERSION'
  end
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
