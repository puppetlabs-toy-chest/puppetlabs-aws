require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:s3_bucket).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    response = s3_client.list_buckets()
    bucket_list = response.buckets.collect do |s3_bucket|

      data = {
        ensure: :present,
        name: s3_bucket.name,
        creation_date: s3_bucket.creation_date,
      }

      begin
        results = s3_client.get_bucket_policy({bucket: s3_bucket.name})
        policy_data = JSON.parse(URI.unescape(results.policy.string))
        policy_document = JSON.pretty_generate(policy_data)
        data[:policy] = policy_document
      rescue Exception => e
        Puppet.debug("An error occurred reading the policy on S3 bucket #{s3_bucket.name}: " + e.message)
      end

      begin
        results = s3_client.get_bucket_lifecycle_configuration({bucket: s3_bucket.name})
        data[:lifecycle_configuration] = JSON.pretty_generate(camelize_stringify_keys(results.to_h))
      rescue Exception => e
        Puppet.debug("An error occurred reading the lifecycle configuration on S3 bucket #{s3_bucket.name}: " + e.message)
      end

      begin
        results = s3_client.get_bucket_encryption({bucket: s3_bucket.name})
        data[:encryption_configuration] = JSON.pretty_generate(camelize_stringify_keys(results.server_side_encryption_configuration.to_h))
      rescue Exception => e
        Puppet.debug("An error occurred reading the encryption configuration on S3 bucket #{s3_bucket.name}: " + e.message)
      end

      new(data)
    end
    bucket_list.reject {|b| b.nil? }
  end

  def self.prefetch(resources)
    instances.each do |prov|
      next if prov.nil?
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end

  def exists?
    Puppet.debug("Checking if S3 bucket #{name} exists")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.debug("Creating S3 Bucket #{name}")
    s3_client.create_bucket({bucket: name})
  end

  def destroy
    Puppet.debug("Destroying S3 Bucket #{name}")
    s3_client.delete_bucket({bucket: name})
  end

  def policy=(value)
    Puppet.debug('Replacing bucket policy')
    s3_client.put_bucket_policy({
      bucket: @property_hash[:name],
      policy: value
    })
  end

  def lifecycle_configuration=(value)
    Puppet.debug('Replacing bucket lifecycle configuration')
    s3_client.put_bucket_lifecycle_configuration({
      bucket: @property_hash[:name],
      lifecycle_configuration: underscore_symbolarize_keys(JSON.parse(value))
    })
  end

  def encryption_configuration=(value)
    Puppet.debug('Replacing bucket encryption configuration')
    s3_client.put_bucket_encryption({
      bucket: @property_hash[:name],
      server_side_encryption_configuration: underscore_symbolarize_keys(JSON.parse(value))
    })
  end

end

private

  def underscore_symbolarize_keys(obj)
    return obj.reduce({}) do |acc, (k, v)|
      acc.tap { |m| m[underscore(k).to_sym] = underscore_symbolarize_keys(v) }
    end if obj.is_a? Hash

    return obj.reduce([]) do |acc, v|
      acc << underscore_symbolarize_keys(v); acc
    end if obj.is_a? Array

    obj
  end

  def camelize_stringify_keys(obj)
    return obj.reduce({}) do |acc, (k, v)|
      acc.tap { |m| m[camelize(k.to_s)] = camelize_stringify_keys(v) }
    end if obj.is_a? Hash

    return obj.reduce([]) do |acc, v|
      acc << camelize_stringify_keys(v); acc
    end if obj.is_a? Array

    obj
  end

  def underscore(str)
    str.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("-", "_").
    downcase
  end

  def camelize(str)
    return "ID" if str == "id"
    return "SSEAlgorithm" if str == "sse_algorithm"
    str.split(/_/).map(&:capitalize).join
  end
