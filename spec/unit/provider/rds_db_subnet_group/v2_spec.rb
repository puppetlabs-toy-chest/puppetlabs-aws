require 'spec_helper'

provider_class = Puppet::Type.type(:rds_db_securitygroup).provider(:v2)

ENV['AWS_ACCESS_KEY_ID'] = 'redacted'
ENV['AWS_SECRET_ACCESS_KEY'] = 'redacted'
ENV['AWS_REGION'] = 'sa-east-1'

describe provider_class do

  let(:resource) {
    Puppet::Type.type(:rds_db_subnet_group).new(
        :name => "supercool_rds_subnet",
        :ensure => 'present',
        :description => 'RDS Test Subnet',
        :subnets => [],
    )
  }

  let(:provider) { resource.provider }

  let(:instance) { provider.class.instances.first }

  it 'should be an instance of the ProviderV2' do
    expect(provider).to be_an_instance_of Puppet::Type::Rds_db_subnet_group::ProviderV2
  end

end
