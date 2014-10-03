require 'spec_helper'

provider_class = Puppet::Type.type(:ec2_instance).provider(:v2)

ENV['AWS_ACCESS_KEY_ID'] = 'redacted'
ENV['AWS_SECRET_ACCESS_KEY'] = 'redacted'

describe provider_class do

  context 'with the minimum params' do
    before(:each) do
      @resource = Puppet::Type.type(:ec2_instance).new(
        name: 'test',
        image_id: '123',
        instance_type: 'x1.gigantic',
        availability_zone: 'us-west-2a',
        region: 'us-west-2'
      )
      @provider = provider_class.new(@resource)
    end

    it 'should be an instance of the ProviderV2' do
      expect(@provider).to be_an_instance_of Puppet::Type::Ec2_instance::ProviderV2
    end

    context 'exists?' do
      it 'should correctly report non-existent instances' do
      end

      it 'should correctly find existing instances' do
      end
    end

    context 'create' do
    end

    context 'destroy' do
    end

  end

end
