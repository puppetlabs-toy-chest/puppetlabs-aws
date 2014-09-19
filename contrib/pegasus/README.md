[Pegasus](https://github.com/puppetlabs/pegasus) is a tool for "system
bootstrap and remote command execution" which sounds like it should be
handy when setting up an entire infrastructure.

This directory should eventually contain some example bundles and plays,
for the moment it just contains an EC2 inventory file. The doesn't sound
interestin until you realise you can do things like run `uname` on all
your EC2 nodes in a region:

    pegasus --nodes <(./ec2-inventory.rb) run 'uname -a' --no-stricthostkeychecking

Region is specied with a `AWS_REGION` environment variable, or via the
`--region` command line flag. You can also filter by tag. Want to ask
all webservers what version of Puppet they are running?

    pegasus --nodes <(./ec2-inventory.rb --tag=type:webserver) run 'puppet --version' --no-stricthostkeychecking
