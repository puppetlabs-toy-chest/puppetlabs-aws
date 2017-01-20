require 'spec_helper'

type_class = Puppet::Type.type(:sqs_queue)

describe type_class do
  context "expected values" do
    let :params do
      [
          :name,
      ]
    end

    let :properties do
      [
          :ensure,
          :region,
          :delay_seconds,
          :maximum_message_size,
          :message_retention_period,
          :visibility_timeout,
      ]
    end


    it 'should have expected properties' do
      properties.each do |property|
        expect(type_class.properties.map(&:name)).to be_include(property)
      end
    end

    it 'should create a valid instance' do
      type_class.new({name: 'name', region: 'sa-east-1'})
    end

    it 'should set delay seconds should get set with a valid value' do
      queue = type_class.new({name: 'queue', region: 'sa-east-1', delay_seconds: 450})
      expect(queue[:delay_seconds]).to eq("450")
    end

    it 'delay seconds should default to 0' do
      queue = type_class.new({name: 'queue', region: 'sa-east-1'})
      expect(queue[:delay_seconds]).to eq("0")
    end

    it 'visibility_timeout should default to 30' do
      queue = type_class.new({name: 'queue', region: 'sa-east-1'})
      expect(queue[:visibility_timeout]).to eq('30')
    end

    it 'should set visibility_timeout with a valid value' do
      queue = type_class.new({name: 'queue', region: 'sa-east-1', visibility_timeout: 123})
      expect(queue[:visibility_timeout]).to eq("123")
    end

    it 'should set message_retention_period should get set with a valid value' do
      queue = type_class.new({name: 'queue', region: 'sa-east-1', message_retention_period: 360})
      expect(queue[:message_retention_period]).to eq("360")
    end

    it 'should set message_retention_period to default to 345600' do
      queue = type_class.new({name: 'queue', region: 'sa-east-1'})
      expect(queue[:message_retention_period]).to eq("345600")
    end

    it 'should set maximum_message_size should get set with a valid value' do
      queue = type_class.new({name: 'queue', region: 'sa-east-1', maximum_message_size: 2048})
      expect(queue[:maximum_message_size]).to eq("2048")
    end

    it 'should set maximum_message_size to default to 262144' do
      queue = type_class.new({name: 'queue', region: 'sa-east-1'})
      expect(queue[:maximum_message_size]).to eq("262144")
    end

    it 'should have expected parameters' do
      params.each do |param|
        expect(type_class.parameters).to be_include(param)
      end
    end
  end
  context 'erroring values' do
    it 'should error with incorrect range value for delay seconds' do
      expect do
        type_class.new({name: 'queue', region: 'sa-east-1', delay_seconds: 1024})
      end.to raise_error(Puppet::Error, /delay_seconds must be an integer between 0 and 900/)
    end

     it 'should require something that looks like a region' do
      expect do
        type_class.new ({name: 'somename', :region => 'sa-east-1 '})
      end.to raise_error(Puppet::Error, /region should be a valid AWS region/)
      expect do
        type_class.new ({name: 'somename', :region => 1})
      end.to raise_error(Puppet::Error, /region should be a String/)
     end

     it 'should require a non-blank region' do
      expect do
        type_class.new ({name: 'somename', region: ''})
      end.to raise_error(Puppet::Error, /region should be a valid AWS region/)
    end
    it 'should require a name' do
      expect do
        type_class.new({})
      end.to raise_error(Puppet::Error, 'Title or name must be provided')
    end

    it 'should require a non-blank name' do
      expect do
        type_class.new({name: ''})
      end.to raise_error(Puppet::Error, /Queue name cannot be blank/)
    end
  end
end
