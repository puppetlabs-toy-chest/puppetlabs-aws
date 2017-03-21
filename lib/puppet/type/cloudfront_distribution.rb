require_relative '../../puppet_x/puppetlabs/property/tag.rb'

Puppet::Type.newtype(:cloudfront_distribution) do
  @doc = 'Type representing a CloudFront distribution.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the distribution to manage.'
    validate do |value|
      fail Puppet::Error, 'Empty distribution names are not allowed' if value == ''
    end
  end

  newproperty(:arn) do
    desc 'Read-only unique AWS resource name assigned to the distribution'
  end

  newproperty(:id) do
    desc 'Read-only unique distribution ID'
  end

  newproperty(:status) do
    desc 'Read-only status of the distribution'
  end

  newproperty(:comment) do
    desc 'Comment for the distribution'
  end

  newproperty(:enabled, :boolean => true) do
    desc 'If the distribution is enabled'
    defaultto true
  end

  newproperty(:price_class) do
    desc 'Price class of the distribution'
    defaultto 'all'
    validate do |value|
      fail "Invalid price class '#{value}'" unless ['all', '100', '200'].include? value
    end
  end

  newproperty(:origins, :array_matching => :all) do
    desc 'Array of origins for the distribution'
    validate do |value|
      fail 'Origin requires an ID' unless value['id']
      fail 'Origin requires a domain name' unless value['domain_name']

      case value['type'].downcase
      when nil, 'custom'
        if value['http_port'] then
          fail 'Invalid HTTP port number' unless value['http_port'].to_i > 0
        end
        if value['https_port'] then
          fail 'Invalid HTTPS port number' unless value['https_port'].to_i > 0
        end
        if value['protocol_policy'] then
          fail 'Invalid protocol policy' unless value['protocol_policy'].all? do |policy|
            ['match-viewer', 'http-only', 'https-only'].include? policy.downcase
          end
        end
        if value['protocols'] then
          fail 'Invalid protocol set' unless value['protocols'].all? do |proto|
            ['SSLv3', 'TLSv1', 'TLSv1.1', 'TLSv1.2'].include? proto
          end
        end
      when 's3'
        fail 'S3 origins are not supported'
      else
        fail "Unknown origin type: #{value['type']}"
      end
    end

    munge do |value|
      clean = {
        # Default origin type to custom
        'type' => value['type'] ? value['type'].downcase : 'custom',
        # Default to no path
        'path' => value['path'] ? value['path'] : '',
        # Make ports ints and default to 80 and 443
        'http_port' => value['http_port'] ? value['http_port'] : '80',
        'https_port' => value['https_port'] ? value['https_port'] : '443',
        # Default protocol policy to match viewer
        'protocol_policy' => value['protocol_policy'] ? value['protocol_policy'].downcase : 'match-viewer',
        # Default protocols to any TLS
        'protocols' => value['protocols'] ? value['protocols'] : ['TLSv1', 'TLSv1.1', 'TLSv1.2'],
      }

      value.merge clean
    end

    def insync?(is)
      provider.class.normalize_values(is) == provider.class.normalize_values(should)
    end
  end

  newproperty(:tags, :parent => PuppetX::Property::AwsTag) do
    desc 'The tags for the distribution'
  end

end
