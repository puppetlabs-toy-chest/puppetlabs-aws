require 'spec_helper_acceptance'

describe "The AWS module" do
  before(:all) do
    @default_region = 'us-east-1'
    @name = "cc-test"
    @aws = AwsHelper.new(@default_region)
  end
  include_context 'cleanse AWS resources for the test'
end
