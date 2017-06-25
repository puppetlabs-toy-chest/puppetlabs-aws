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

end
