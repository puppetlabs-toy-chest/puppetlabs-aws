require 'spec_helper'

[
  :route53_a_record,
  :route53_txt_record,
  :route53_ns_record,
].each do |type|

  type_class = Puppet::Type.type(type)

  describe type_class do

    let :params do
      [
        :name,
      ]
    end

    let :properties do
      [
        :ensure,
        :ttl,
        :values,
        :zone,
      ]
    end

    it 'should have expected properties' do
      properties.each do |property|
        expect(type_class.properties.map(&:name)).to be_include(property)
      end
    end

    it 'should have expected parameters' do
      params.each do |param|
        expect(type_class.parameters).to be_include(param)
      end
    end

    it 'should require a name' do
      expect {
        type_class.new({})
      }.to raise_error(Puppet::Error, 'Title or name must be provided')
    end

    it 'should require a name with a trailing period' do
      expect {
        type_class.new({ name: 'invalid' })
      }.to raise_error(Puppet::Error, /Record names must end with a \./)
    end

    it 'should require a zone with a trailing period' do
      expect {
        type_class.new({ name: 'valid.', zone: 'invalid' })
      }.to raise_error(Puppet::Error, /Zone names must end with a \./)
    end

    context 'with a full set of properties' do
      before :all do
        @instance = type_class.new({ name: 'valid.', zone: 'valid.', ttl: "400" })
      end

      it 'should convert ttl values to an integer' do
        expect(@instance[:ttl].kind_of?(Integer)).to be true
      end
    end

  end

end
