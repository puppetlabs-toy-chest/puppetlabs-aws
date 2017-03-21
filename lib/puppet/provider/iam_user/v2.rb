require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:iam_user).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.get_users
    user_results = iam_client.list_users()
    users = user_results.users

    truncated = user_results.is_truncated
    marker = user_results.marker

    while truncated and marker
      Puppet.debug('iam_user results truncated, proceeding with discovery')
      response = iam_client.list_users({marker: marker})
      response.users.each {|u| users << u }
      truncated = response.is_truncated
      marker = response.marker
    end

    users
  end

  def self.instances
    users = get_users()
    users.collect do |user|
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
      begin
        iam_client.delete_login_profile({user_name: user.user_name})
      rescue => e
        Puppet.debug("Failed to delete the login profile for user #{user.user_name}: #{e.message}")
      end

      begin
        iam_client.list_access_keys({user_name: user.user_name}).access_key_metadata.each {|k|
          iam_client.delete_access_key({
            user_name: user.user_name,
            access_key_id: k['access_key_id'],
          })
        }
      rescue => e
        Puppet.debug("Failed to delete the access keys for user #{user.user_name}: #{e.message}")
      end

      begin
        iam_client.list_mfa_devices({user_name: user.user_name}).mfa_devices.each {|k|

          iam_client.deactivate_mfa_device({
            user_name: user.user_name,
            serial_number: k['serial_number'],
          })

          iam_client.delete_virtual_mfa_device({
            serial_number: k['serial_number'],
          })
        }
      rescue => e
        Puppet.debug("Failed to delete the MFA devices for user #{user.user_name}: #{e.message}")
      end

      iam_client.delete_user({user_name: user.user_name})
    end
    @property_hash[:ensure] = :absent
  end

end
