require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:iam_user).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    response = iam_client.list_users()
    response.users.collect do |user|
      new({
        name: user.user_name,
        ensure: :present,
        path: user.path
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
    Puppet.debug("Checking if IAM user #{name} exists")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating IAM user #{name}")
    iam_client.create_user({ user_name: name })
    @property_hash[:ensure] = :present
  end

  def destroy
    Puppet.info("Deleting IAM user #{name}")
    users = iam_client.list_users.users.select { |user| user.user_name == name }
    users.each do |user|
      iam_client.delete_user({user_name: user.user_name})
    end
    @property_hash[:ensure] = :absent
  end

end
