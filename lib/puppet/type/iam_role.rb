Puppet::Type.newtype(:iam_role) do
  @doc = 'Type representing IAM role.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the role to manage.'
    validate do |value|
      fail Puppet::Error, 'Empty role names are not allowed' if value == ''
    end
  end

  newproperty(:path) do
    desc 'The path to the role.'
    defaultto '/'

    validate do |value|
      unless value =~ /^[^\0]+$/
        raise ArgumentError , "'%s' is not a valid path" % value
      end
    end
  end

  newproperty(:policy_document) do
    desc 'The policy document JSON string'
    defaultto '{"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Principal": {"Service": "ec2.amazonaws.com"}, "Action": "sts:AssumeRole"}]}'

    validate do |value|
      fail Puppet::Error, 'Policy documents must be JSON strings' unless value.is_a? String
    end

    munge do |value|
      begin
        data = JSON.parse(CGI::unescapeHTML(value))
        JSON.pretty_generate(data)
      rescue Exception => e
        fail("Document string is not valid JSON: #{e}")
      end
    end
  end

  newproperty(:arn)

end
