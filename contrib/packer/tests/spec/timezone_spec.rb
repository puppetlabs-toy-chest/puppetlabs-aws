require 'spec_helper'

describe package('tzdata') do
  it { should be_installed }
end
