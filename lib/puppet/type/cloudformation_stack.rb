require_relative '../../puppet_x/puppetlabs/property/tag.rb'
require 'puppet/parameter/boolean'

Puppet::Type.newtype(:cloudformation_stack) do
  @doc = '
    Type representing a CloudFormation stack.

    Example:

    cloudformation_stack { \'s3-bucket-test\':
      ensure        => updated,
      region        => \'us-west-2\',
      template_url  => \'https://s3-us-west-2.amazonaws.com/cloudformation-templates-us-west-2/S3_Website_Bucket_With_Retain_On_Delete.template\',
    }
    '

  newproperty(:ensure) do
    desc '
      The ensure value for the stack.
      "present" will create the stack but not apply updates.
      "updated" will create or apply any updates to the stack.
      "absent" will delete the stack.'
    newvalue(:present) do
      provider.create if !provider.exists?
    end
    newvalue(:updated)
    newvalue(:absent) do
      provider.destroy if provider.exists?
    end
    def change_to_s(current, desired)
      current = :updated if current == :present
      desired = :updated if desired == :present
      current == desired ? current : "changed #{current} to #{desired}"
    end
    def insync?(is)
      return is.to_s == should.to_s unless should.to_s == 'updated'
      if !provider.exists?
        provider.create
        return true
      else
        # provider.update will return true when updates applied, otherwise false
        return !provider.update
      end
    end
  end

  newparam(:name, namevar: true) do
    desc 'The name of the stack.'
    validate do |value|
      fail 'Stacks must have a name' if value == ''
      fail 'name should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:capabilities, :array_matching => :all) do
    desc 'The list of stack capabilities, including CAPABILITY_IAM, CAPABILITY_NAMED_IAM, an empty list, or unspecified.'
    def insync?(is)
      is.to_set == should.to_set
    end
    validate do |value|
      fail 'Capabilities array must contain one or more of \'CAPABILITY_IAM\' or \'CAPABILITY_NAMED_IAM\'.' \
        unless value == 'CAPABILITY_IAM' or value == 'CAPABILITY_NAMED_IAM'
    end
  end

  newproperty(:change_set_id) do
    desc 'Unique identifier of the stack. (readonly)'
  end

  newproperty(:creation_time) do
    desc 'The time at which the stack was created. (readonly)'
  end

  newproperty(:description) do
    desc 'A user-defined description associated with the stack. (readonly)'
  end

  newparam(:disable_rollback, :boolean => true, :parent => Puppet::Parameter::Boolean) do
    desc 'Whether to disable rollback on stack creation failures. (boolean)'
  end

  newproperty(:id) do
    desc 'The unique ID of the stack. (readonly)'
  end

  newproperty(:last_updated_time) do
    desc 'The time the stack was last updated. (readonly)'
  end

  newproperty(:notification_arns, :array_matching => :all) do
    desc 'List of SNS topic ARNs to which stack related events are published.'
    def insync?(is)
      is.to_set == should.to_set
    end
    validate do |value|
      fail 'notification_arns should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:on_failure) do
    desc 'Determines what action will be taken if stack creation fails. This must be one of: "DO_NOTHING", "ROLLBACK", or "DELETE". You can specify either on_failure or disable_rollback, but not both.'
    newvalues('DO_NOTHING', 'ROLLBACK', 'DELETE')
  end

  newproperty(:outputs) do
    desc 'A hash of stack outputs. (readonly)'
    def should_to_s(value)
      value.inspect
    end
    def is_to_s(value)
      value.inspect
    end
  end

  newproperty(:parameters) do
    desc 'A hash of input parameters.'
    def insync?(is)
      is == should
    end
    def should_to_s(value)
      value.inspect
    end
    def is_to_s(value)
      value.inspect
    end
  end

  newparam(:policy_body) do
    desc 'JSON structure containing the stack policy body. For more information, go to Prevent Updates to Stack Resources in the AWS CloudFormation User Guide. You can specify either the policy_body or the policy_url parameter, but not both.'
    validate do |value|
      fail 'policy_body must be a String' unless value.is_a?(String)
    end

    munge do |value|
      begin
        data = JSON.parse(value)
        JSON.pretty_generate(data)
      rescue
        fail('policy_body string is not valid JSON')
      end
    end
  end

  newparam(:policy_url) do
    desc 'Location of a file containing the stack policy. The URL must point to a policy (maximum size: 16 KB) located in an S3 bucket in the same region as the stack. You can specify either the policy_body or the policy_url parameter, but not both.'
    validate do |value|
      fail 'policy_url must be a String' unless value.is_a?(String)
    end
  end

  validate do
    fail "You can specify either policy_body or policy_url but not both for the cloudformation stack [#{self[:name]}]" if self[:policy_body] && self[:policy_url]
  end

  newparam(:resource_types, :array_matching => :all) do
    desc 'The list of resource types that you have permissions to work with for this stack. (optional)'
    def insync?(is)
      is.to_set == should.to_set
    end
    validate do |value|
      fail 'resource_types must be a string.' unless value.is_a?(String)
    end
  end

  newproperty(:role_arn) do
    desc 'The Amazon Resource Name (ARN) of an AWS Identity and Access Management (IAM) role that is associated with the stack.'
    validate do |value|
      fail 'role_arn must be a String' unless value.is_a?(String)
    end
  end

  newproperty(:status) do
    desc 'The status of the stack. (readonly)'
    newvalue(:CREATE_IN_PROGRESS)
    newvalue(:CREATE_FAILED)
    newvalue(:CREATE_COMPLETE)
    newvalue(:ROLLBACK_IN_PROGRESS)
    newvalue(:ROLLBACK_FAILED)
    newvalue(:ROLLBACK_COMPLETE)
    newvalue(:DELETE_IN_PROGRESS)
    newvalue(:DELETE_FAILED)
    newvalue(:DELETE_COMPLETE)
    newvalue(:UPDATE_IN_PROGRESS)
    newvalue(:UPDATE_COMPLETE_CLEANUP_IN_PROGRESS)
    newvalue(:UPDATE_COMPLETE)
    newvalue(:UPDATE_ROLLBACK_IN_PROGRESS)
    newvalue(:UPDATE_ROLLBACK_FAILED)
    newvalue(:UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS)
    newvalue(:UPDATE_ROLLBACK_COMPLETE)
    newvalue(:REVIEW_IN_PROGRESS)
  end

  newparam(:template_body) do
    desc 'Structure containing the template body with a minimum length of 1 byte and a maximum length of 51,200 bytes. For more information, go to Template Anatomy in the AWS CloudFormation User Guide.'
    validate do |value|
      fail 'template_body must be a String' unless value.is_a?(String)
      fail 'template_body must be longer than 1 byte' unless value.size > 1
      fail 'template_body must be shorter than 51,200 bytes' unless value.size < 51200
    end
  end

  newparam(:template_url) do
    desc 'Location of file containing the template body. The URL must point to a template (max size: 460,800 bytes) that is located in an Amazon S3 bucket. For more information, go to the Template Anatomy in the AWS CloudFormation User Guide.'
    validate do |value|
      fail 'template_url must be a String' unless value.is_a?(String)
    end
  end

  validate do
    fail "You can specify either template_body or template_url but not both for the cloudformation stack [#{self[:name]}]" if self[:template_body] && self[:template_url]
  end

  newproperty(:timeout_in_minutes) do
    desc 'The amount of time within which stack creation should complete.'
    validate do |value|
      fail 'timeout_in_minutes must be an positive Integer' unless value.is_a?(Integer) and value >= 0
    end
  end

  newproperty(:tags, :parent => PuppetX::Property::AwsTag) do
    desc 'The tags for the instance.'
  end

  newproperty(:region) do
    desc 'The region in which to launch the stack.'
    validate do |value|
      fail 'region should not contain spaces' if value =~ /\s/
      fail 'region should be a String' unless value.is_a?(String)
    end
  end

end
