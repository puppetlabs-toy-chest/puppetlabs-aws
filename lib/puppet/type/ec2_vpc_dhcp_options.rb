Puppet::Type.newtype(:ec2_vpc_dhcp_options) do
  @doc = "Manage AWS DHCP Options sets"
  newparam(:name)
  ensurable
  newproperty(:tags) # TODO
  newproperty(:region)
  newproperty(:domain_name) do
    validate do |value|
      unless value =~ /^[\w\.-]+$/
        raise ArgumentError , "'%s' is not a valid domain_name" % value
      end
    end
  end
  newproperty(:domain_name_servers, :array_matching => :all)
  newproperty(:ntp_servers, :array_matching => :all)
  newproperty(:netbios_name_servers, :array_matching => :all)
  newproperty(:netbios_node_type) do
    defaultto '2'
    validate do |value|
      unless value =~ /^[1248]$/
        raise ArgumentError , "'%s' is not a valid netbios_node_type, can be [1248]" % value
      end
    end
  end
end

