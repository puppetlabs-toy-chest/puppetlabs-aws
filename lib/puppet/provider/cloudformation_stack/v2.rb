require_relative '../../../puppet_x/puppetlabs/aws.rb'
require 'base64'

Puppet::Type.type(:cloudformation_stack).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws
  confine feature: :retries

  mk_resource_methods
  remove_method :tags=

  def initialize(value={})
    super(value)
    @property_flush = {}
  end

  def self.instances
    regions.collect do |region|
      begin
        stacks = []

        cloudformation_client(region).describe_stacks().each do |response|
          response.data.stacks.each do |stack|
            hash = stack_to_hash(region, stack)
            stacks << new(hash) if has_name?(hash)
          end
        end
        stacks
      rescue Timeout::Error, StandardError => e
        raise PuppetX::Puppetlabs::FetchingAWSDataError.new(region, self.resource_type.name.to_s, e.message)
      end
    end.flatten
  end

  read_only(:change_set_id, :change_set_id, :creation_time, :description,
            :id, :last_update_time, :outputs, :region, :status )

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region
      end
    end
  end

  def self.enable_from_status(status)
    case status
    when 'CREATE_FAILED', 'ROLLBACK_IN_PROGRESS', 'ROLLBACK_COMPLETE',
      'DELETE_IN_PROGRESS', 'DELETE_COMPLETE'
        :absent
    when 'CREATE_IN_PROGRESS', 'CREATE_COMPLETE', 'ROLLBACK_FAILED',
      'DELETE_FAILED'
        :present
    when 'UPDATE_COMPLETE', 'UPDATE_ROLLBACK_FAILED',
      'UPDATE_ROLLBACK_COMPLETE', 'UPDATE_IN_PROGRESS',
      'UPDATE_COMPLETE_CLEANUP_IN_PROGRESS', 'UPDATE_ROLLBACK_IN_PROGRESS',
      'UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS', 'REVIEW_IN_PROGRESS'
        :updated
    end
  end

  def self.stack_to_hash(region, stack)
    name = stack.stack_name
    return {} unless name
    tags = {}
    stack.tags.each do |tag|
      tags[tag.key] = tag.value
    end

    parameters = {}
    stack.parameters.each do |parameter|
      parameters[parameter.parameter_key] = parameter.parameter_value
    end

    outputs = {}
    stack.outputs.each do |output|
      outputs[output.output_key] = output.output_value
    end

    puppet_ensure = enable_from_status(stack.stack_status)

    config = {
      capabilities: stack.capabilities,
      change_set_id: stack.change_set_id,
      creation_time: stack.creation_time,
      description: stack.description,
      disable_rollback: stack.disable_rollback,
      ensure: puppet_ensure,
      id: stack.stack_id,
      last_updated_time: stack.last_updated_time,
      name: name,
      notification_arns: stack.notification_arns,
      outputs: outputs,
      parameters: parameters,
      region: region,
      role_arn: stack.role_arn,
      status: stack.stack_status.to_sym,
      tags: tags,
      timeout_in_minutes: stack.timeout_in_minutes,
    }

    config
  end

  def exists?
    Puppet.debug("Checking if stack #{name} exists in region #{target_region}")
    return false if @property_hash[:status] == nil
    enable = Puppet::Type::Cloudformation_stack::ProviderV2::enable_from_status(@property_hash[:status].to_s)
    return [:present,:updated].include? enable
  end

  def get_config
    parameters = []
    resource[:parameters].each_key { |key|
      parameters.push( {
          parameter_key: key,
          parameter_value: resource[:parameters][key],
          use_previous_value: false,
        }
      )
    } unless resource[:parameters] == nil

    tags = []
    resource[:tags].each_key { |key|
      tags.push( {
          key: key,
          value: resource[:tags][key],
        }
      )
    } unless resource[:tags] == nil

    {
      stack_name: resource[:name], # required
      template_body: resource[:template_body],
      template_url: resource[:template_url],
      parameters: parameters,
      disable_rollback: resource[:disable_rollback],
      timeout_in_minutes: resource[:timeout_in_minutes],
      notification_arns: resource[:notification_arns],
      capabilities: resource[:capabilities], # accepts CAPABILITY_IAM, CAPABILITY_NAMED_IAM
      resource_types: resource[:resource_types],
      role_arn: resource[:role_arn],
      on_failure: resource[:on_failure], # accepts DO_NOTHING, ROLLBACK, DELETE
      stack_policy_body: resource[:policy_body],
      stack_policy_url: resource[:policy_url],
      tags: tags,
    }
  end

  def create
    Puppet.info("Starting stack #{name} in region #{resource[:region]}")

    cloudformation = cloudformation_client(resource[:region])

    config = get_config
    response = cloudformation.create_stack(config)

    @property_hash[:ensure] = :present
  end

  def update
    cloudformation = cloudformation_client(resource[:region])
    config = get_config

    # disable_rollback, on_failure, and timeout_in_minutes only apply during
    # stack creation.
    config.delete(:disable_rollback)
    config.delete(:on_failure)
    config.delete(:timeout_in_minutes)

    begin
      response = cloudformation.update_stack(config)
      Puppet.info("Updated stack #{name} in region #{resource[:region]}")
      @property_hash[:ensure] = :updated
      return true
    rescue Aws::CloudFormation::Errors::ServiceError => e
      fail e unless e.message == 'No updates are to be performed.'
      @property_hash[:ensure] = :updated
      return false
    end
  end

  def destroy
    Puppet.info("Deleting stack #{name} in region #{target_region}")
    cloudformation = cloudformation_client(target_region)

    cloudformation.delete_stack({
      stack_name: name,
      retain_resources: [],
      role_arn: nil,
    })
    cloudformation.wait_until(:stack_delete_complete, stack_name: name)
    @property_hash[:ensure] = :absent
  end

end
