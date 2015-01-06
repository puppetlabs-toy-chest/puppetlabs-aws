require 'spec_helper'

type_class = Puppet::Type.type(:ec2_vpc_dhcp_options)

describe type_class do

  let :params do
    [
      :name,
    ]
  end

  let :properties do
    [
      :ensure,
      :tags,
      :region,
      :domain_name,
      :domain_name_servers,
      :ntp_servers,
      :netbios_name_servers,
      :netbios_node_type,
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
end
