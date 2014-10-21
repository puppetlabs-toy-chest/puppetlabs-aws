[Packer](http://www.packer.io) is a tool used to create virtual machine
images, in this case AMIs for use in EC2. This example uses Puppet to
install a minimal set of packages on an image and runs a
[Serverspec](http://serverspec.org) test suite to verify everything
worked, before publishing the AMI to EC2.

> FOR THIS EXAMPLE ONLY. This code currently adds a `garethr` user
> and a public key to the created AMI.

## Usage

With packer installer, first download the required puppet modules:

    bundle exec librarian-puppet install

Then to build the AMI run:

    packer build template.json
