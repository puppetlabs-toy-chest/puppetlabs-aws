require_relative '../../puppet_x/puppetlabs/property/region.rb'

Puppet::Type.newtype(:ec2_elastic_ip) do
  @doc = "Type representing an Elastic IP and it's association."

  newproperty(:ensure) do
    newvalue(:attached) do
      provider.create
    end

    newvalue(:detached) do
      provider.destroy
    end
    defaultto { :detached }
  end

  newparam(:name, namevar: true) do
    desc 'The IP address of the Elastic IP.'
    validate do |value|
      fail 'The name of an Elastic IP address must be a valid IP.' unless value =~ Resolv::IPv4::Regex
    end
  end

  newproperty(:region, :parent => PuppetX::Property::AwsRegion) do
    desc 'The name of the region in which the Elastic IP is found.'
  end

  newproperty(:instance) do
    desc 'The name of the instance associated with the Elastic IP.'
    validate do |value|
      fail 'instance should be a String' unless value.is_a?(String)
      fail 'You must provide an instance for the Elastic IP association' if value.nil? || value.empty?
    end
  end

  autorequire(:ec2_instance) do
    self[:instance]
  end

end
