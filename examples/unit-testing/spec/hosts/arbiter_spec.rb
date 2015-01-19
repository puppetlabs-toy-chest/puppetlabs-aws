require 'spec_helper'

describe 'arbiter' do
  it { should compile.with_all_deps }
  it { should have_ec2_instance_resource_count(2) }

  2.times do |i|
    it { should contain_ec2_instance("web#{i+1}").with_region('sa-east-1').with_instance_type('t1.micro') }
  end
end
