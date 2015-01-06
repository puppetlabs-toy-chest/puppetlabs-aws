require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))

Puppet::Type.type(:aws_cgw).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
  mk_resource_methods
  remove_method :tags= # We want the method inherited from the parent
  def self.new_from_aws(region_name, item)
    tags = item.tags.to_h
    name = tags.delete('Name') || item.id
    new(
      :aws_item   => item,
      :name       => name,
      :id         => item.id,
      :bgp_asn    => item.bgp_asn,
      :type       => 'ipsec.1', # FIXME
      :region     => region_name,
      :ip_address => item.ip_address,
      :ensure     => :present,
      :tags       => tags
    )
  end
  def self.instances()
    regions.collect do |region_name|
      ec2.regions[region_name].customer_gateways.reject { |item| item.state == :deleting or item.state == :deleted }.collect { |item| new_from_aws(region_name,item) }
    end.flatten
  end

  read_only(:ip_address, :bgp_asn, :region, :type)

  def create
    begin
      fail "Cannot create aws_cgw #{resource[:title]} without a region" unless resource[:region]
      region = ec2.regions[resource[:region]]
      fail "Cannot find region '#{resource[:region]} for resource #{resource[:title]}" unless region
      cgw = region.customer_gateways.create(resource[:bgp_asn].to_i, resource[:ip_address])
      tag_with_name cgw, resource[:name]
      tags = resource[:tags] || {}
      tags.each { |k,v| cgw.add_tag(k, :value => v) }
      cgw
    rescue Exception => e
      fail e
    end
  end
  def destroy
    @property_hash[:aws_item].delete
    @property_hash[:ensure] = :absent
  end
end

