require 'spec_helper'

describe package('locales') do
  it { should be_installed }
end
