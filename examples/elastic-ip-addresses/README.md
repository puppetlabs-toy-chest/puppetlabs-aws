# Managing Elastic IP Address Associations

[Elastic IP
addresses](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/elastic-ip-addresses-eip.html)
are static IPs assigned to your AWS account that can be
associated with an EC2 instance. The AWS Puppet module allows for
attaching these IP addresses to instances managed by Puppet.

## What

For this example, we'll create two instances, and attach an Elastic IP
to one of them. We'll then switch that IP address to the second
instance.

## How

First, you'll need to allocate an Elastic IP to your account. The Amazon
documentation [explains how to do
this](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/elastic-ip-addresses-eip.html#using-instance-addressing-eips-allocating).
The easiest ways of doing that are from the AWS console, or from the
command line tools like so:

    aws ec2 allocate-address --region sa-east-1

Once you have the IP address, you need to modify the manifest in `init.pp`.
This is because the IP address present in the file is already allocated to
a different account, and IP addresses are unique.

With the module installed as described in the README, from this directory run:

    puppet apply init.pp

This creates the instances and associates the IP address to the one
called `web-1`. We can see that by running:

    puppet resource ec2_elastic_ip

Which should return something like:

~~~puppet
ec2_elastic_ip { '177.71.189.57':
  ensure   => 'attached',
  instance => 'web-1',
  region   => 'sa-east-1',
}
~~~

We can now use `puppet resource` to switch the IP to the `web-2` instance:

    puppet resource ec2_elastic_ip 177.71.189.57 region=sa-east-1 region=sa-east-1 instance=web-2
