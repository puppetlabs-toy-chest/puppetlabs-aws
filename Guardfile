notification :off

guard 'rake', :task => 'spec' do
  watch(%r{^manifests\/.+\.pp$})
  watch(%r{^spec\/.+\.rb$})
end
