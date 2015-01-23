require 'spec_helper'

provider_class = Puppet::Type.type(:rds_instance).provider(:v2)

ENV['AWS_ACCESS_KEY_ID'] = 'redacted'
ENV['AWS_SECRET_ACCESS_KEY'] = 'redacted'
ENV['AWS_REGION'] = 'sa-east-1'

describe provider_class do

  let(:resource) {
    Puppet::Type.type(:rds_instance).new(
      ensure: 'present',
      name: 'awesome-db-5',
      region: 'us-west-1',
      db_name:  'mysqldbname3',
      engine: 'mysql',
      engine_version: '5.6.19a',
      license_model: 'general-public-license',
      allocated_storage: 10,
      availability_zone: 'us-west-1a',
      storage_type: 'gp2',
      db_instance_class: 'db.m3.medium',
      master_username: 'awsusername',
      master_user_password: 'the-master-password',
      multi_az: false,
    )
  }

  let(:provider) { resource.provider }

  let(:instance) { provider.class.instances.first }

  it 'should be an instance of the ProviderV2' do
    expect(provider).to be_an_instance_of Puppet::Type::Rds_instance::ProviderV2
  end

end