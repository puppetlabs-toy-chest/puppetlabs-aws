Puppet::Type.newtype(:s3_bucket) do
  @doc = 'Type representing S3 buckets.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the bucket to manage.'
    validate do |value|
      fail Puppet::Error, 'Empty bucket names are not allowed' if value == ''
    end
  end

  newproperty(:creation_date) do
    desc 'Read-only property for the date a bucket was created'
  end

  newproperty(:policy) do
    desc 'The policy document JSON string to apply'
    validate do |value|
      fail Puppet::Error, 'Policy documents must be JSON strings' unless is_valid_json?(value)
    end

    munge do |value|
      begin
        JSON.pretty_generate(JSON.parse(value))
      rescue
        fail('Policy string is not valid JSON')
      end
    end
  end

  newproperty(:lifecycle_configuration) do
    desc 'The lifecycle configuration document JSON string to apply'
    validate do |value|
      fail Puppet::Error, 'Lifecycle configuration documents must be JSON strings' unless is_valid_json?(value)
    end

    munge do |value|
      begin
        JSON.pretty_generate(JSON.parse(value))
      rescue
        fail('Lifecycle configuration string is not valid JSON')
      end
    end
  end

  newproperty(:encryption_configuration) do
    desc 'The bucket encryption document JSON string to apply'
    validate do |value|
      fail Puppet::Error, 'Bucket encryption documents must be JSON strings' unless is_valid_json?(value)
    end

    munge do |value|
      begin
        JSON.pretty_generate(JSON.parse(value))
      rescue
        fail('Bucket encryption string is not valid JSON')
      end
    end
  end

end

private

  def is_valid_json?(string)
    !!JSON.parse(string)
  rescue JSON::ParserError => _e
    false
  end

