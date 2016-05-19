Puppet::Type.newtype(:iam_user) do
  @doc = 'Type representing IAM users.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the user to manage.'
    validate do |value|
      fail Puppet::Error, 'Empty usernames are not allowed' if value == ''
    end
  end
end
