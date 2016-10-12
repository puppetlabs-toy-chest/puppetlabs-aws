Puppet::Type.newtype(:sqs_queue) do
  @doc = "Type representing a SQS Queue"
  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the SQS queue'
    validate do |value|
      fail 'Queue name must be a string' unless value.is_a?(String)
      fail 'Queue name cannot be blank' if value.nil? || value.empty?
      fail 'The name of a SQS queue must contain only alphanumeric characters,dashes or underscores' unless value =~ /[\w-]+/
    end
  end

  newparam(:url) do
    desc 'The URL of an existing queue - read only parameter'
  end

  newproperty(:delay_seconds) do
    desc 'The time in seconds that the delivery of all messages in the queue will be delayed'
    defaultto "0"
    validate do |value|
      fail "delay_seconds must be an integer between 0 and 900" if value.to_i < 0 || value.to_i > 900
    end
    munge(&:to_s)
  end

  newproperty(:message_retention_period) do
    desc 'The number of seconds Amazon SQS retains a message.'
    defaultto "345600"
    validate do |value|
      fail "message_retention_period must be an integer between 60 and 1209600" if value.to_i < 60 || value.to_i > 1209600
    end

    munge(&:to_s)
  end

  newproperty(:maximum_message_size) do
    desc 'The limit of how many bytes a message can contain before Amazon SQS rejects it.'
    defaultto "262144"
    validate do |value|
      fail "maximum_message_size must be an integer between 1024 and 262144" if value.to_i < 1024 || value.to_i > 262144
    end
     munge(&:to_s)
  end

  newproperty(:region) do
    desc 'The name of the region in which the SQS queue is located'
    validate do |value|
      fail 'region should be a String' unless value.is_a?(String)
      fail 'You must provide a non-blank region name for SQS Queues' if value.nil? || value.empty?
      fail 'The name of a region should contain only alphanumeric characters or dashes' unless value =~ /^([a-zA-Z]+-+)+\d$/
    end
  end

  newproperty(:visibility_timeout) do
    desc 'The number of seconds during which Amazon SQS prevents other consuming components from receiving and processing a message'
    defaultto '30'
    validate do |value|
      fail "visibility_timeout must be an integer between 60 and 43200" if value.to_i < 0 || value.to_i > 43200
    end

    munge(&:to_s)
  end
end
