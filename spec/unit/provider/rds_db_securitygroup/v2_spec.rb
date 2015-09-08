require 'spec_helper'

provider_class = Puppet::Type.type(:rds_db_securitygroup).provider(:v2)

ENV['AWS_ACCESS_KEY_ID'] = 'redacted'
ENV['AWS_SECRET_ACCESS_KEY'] = 'redacted'
ENV['AWS_REGION'] = 'sa-east-1'

describe provider_class do

  let(:resource) {
    Puppet::Type.type(:rds_db_securitygroup).new(
      :name => "awesome-db_securitygroup",
      :ensure => 'present',
      :description => 'DB Security Group',
    )
  }

  let(:provider) { resource.provider }

  let(:instance) { provider.class.instances.first }

  it 'should be an instance of the ProviderV2' do
    expect(provider).to be_an_instance_of Puppet::Type::Rds_db_securitygroup::ProviderV2
  end

end
