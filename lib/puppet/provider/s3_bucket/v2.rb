require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:s3_bucket).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    response = s3_client.list_buckets()
    response.buckets.collect do |bucket|
      new({
        ensure: :present,
        name: bucket.name,
        creation_date: bucket.creation_date,
      })
    end
  end

  def self.prefetch(resources)
    instances.each do |prov|
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

end
