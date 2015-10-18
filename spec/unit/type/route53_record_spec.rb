require 'spec_helper'

[
  :route53_a_record,
  :route53_txt_record,
  :route53_ns_record,
  :route53_aaaa_record,
  :route53_cname_record,
  :route53_mx_record,
  :route53_ptr_record,
  :route53_spf_record,
  :route53_srv_record,
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

    it 'should require ttl to be a number' do
      expect {
        type_class.new({ name: 'valid.', ttl: 'invalid' })
      }.to raise_error(Puppet::Error, /TTL values must be integers/)
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

describe Puppet::Type.type(:route53_txt_record) do

  it 'should add additional quotes around values' do
    record = Puppet::Type.type(:route53_txt_record).new({
      name: 'example.com.',
      ttl: 3000,
      zone: 'example.com.',
      values: 'value',
    })
    expect(record[:values]).to eq(["\"value\""])
  end

  it 'should not add additional quotes around values if already present' do
    record = Puppet::Type.type(:route53_txt_record).new({
      name: 'example.com.',
      ttl: 3000,
      zone: 'example.com.',
      values: '"value"',
    })
    expect(record[:values]).to eq(["\"value\""])
  end


end
