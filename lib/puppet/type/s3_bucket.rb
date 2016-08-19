Puppet::Type.newtype(:s3_bucket) do
  @doc = 'Type representing S3 buckets.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the user to manage.'
    validate do |value|
      fail Puppet::Error, 'Empty bucket names are not allowed' if value == ''
    end
  end

  newproperty(:creation_date) do
    desc 'Read-only property for the date a bucket was created'
  end

end

