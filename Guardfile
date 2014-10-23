notification :off

scope group: :specs

group :specs do
  guard :rake, :task => 'spec' do
    watch(%r{^lib\/.+\.rb$})
    watch(%r{^spec\/.+\.rb$})
  end
end

group :acceptance do
  guard :rake, :task => 'acceptance' do
    watch(%r{^lib\/.+\.rb$})
    watch(%r{^spec\/acceptance\/.+\.rb$})
  end
end
