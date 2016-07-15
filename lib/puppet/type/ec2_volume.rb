require_relative '../../puppet_x/puppetlabs/property/tag.rb'

Puppet::Type.newtype(:ec2_volume) do
  @doc= 'Type representing EC2 Volumes'

  ensurable

  newparam(:name, namevar: true) do
    validate do |value|
      fail Puppet::Error, 'Empty volume names are not allowed' if value == ''
    end
  end

  newproperty(:volume_id)
  newproperty(:volume_type)
  newproperty(:size)
  newproperty(:state)
  newproperty(:availability_zone) do
    isrequired
  end

  newproperty(:tags, :parent => PuppetX::Property::AwsTag) do
    desc 'The tags for the instance.'
  end

end

