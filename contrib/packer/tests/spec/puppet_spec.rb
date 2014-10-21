require 'spec_helper'

describe package('puppet') do
  it { should be_installed }
end
