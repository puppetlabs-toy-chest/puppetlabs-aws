Puppet::Type.newtype(:ec2_vpc) do
  @doc = 'type representing an EC2 VPC'

  ensurable

  newparam(:name, namevar: true) do
    desc 'the name of the VPC'
    validate do |value|
      fail Puppet::Error, 'Empty values are not allowed' if value == ''
    end
  end

  newproperty(:cidr_block) do
    desc 'the classless inter-domain routing block for this VPC'
  end

  newproperty(:region) do
    desc 'the region in which to launch the VPC'
  end

end
