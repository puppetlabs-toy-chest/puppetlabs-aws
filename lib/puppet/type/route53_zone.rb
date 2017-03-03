require 'puppet/property/boolean'
require_relative '../../puppet_x/puppetlabs/property/tag.rb'
require_relative '../../puppet_x/puppetlabs/property/region.rb'

Puppet::Type.newtype(:route53_zone) do
  @doc = 'Type representing a Route53 DNS zone.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of DNS zone.'
    validate do |value|
      fail Puppet::Error, 'Empty zone names are not allowed.' if value.empty?
    end

    munge do |value|
      # Ensure trailing dot.
      value[-1] == '.' ? value : "#{value}."
    end
  end

  newproperty(:is_private, boolean: true, parent: Puppet::Property::Boolean) do
    desc 'Whether the DNS zone is private or public. Private zones require associated VPCs.'
    defaultto false
  end

  newproperty(:id) do
    desc 'AWS-generated ID of the DNS zone.'
  end

  newproperty(:record_count) do
    desc 'Number of records in the DNS zone.'
  end

  newproperty(:comment) do
    desc 'Comment on the DNS zone.'
  end

  newproperty(:tags, parent: PuppetX::Property::AwsTag) do
    desc 'Tags on the DNS zone.'
  end

  newproperty(:vpcs, array_matching: :all, parent: PuppetX::Property::AwsRegion) do
    desc 'For private zones, the associated VPCs.'

    # Validate any VPCs specified, even though only private zones use them.
    validate do |value|
      # Validate region with PuppetX::Property::AwsRegion.
      super(value['region'])
      fail 'Missing VPC name.' if value['vpc'].nil? or value['vpc'].empty?
    end

    def insync?(is)
      is - should == should - is
    end
  end

end
