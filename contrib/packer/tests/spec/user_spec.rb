require 'spec_helper'

describe user('ubuntu') do
  it { should exist }
end

describe user('garethr') do
  it { should exist }
  it { should belong_to_group 'sudo' }
end
