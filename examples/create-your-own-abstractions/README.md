# Create your own abstractions

When describing any complex domain like your infrastructure, it's
important that you can introduce your own higher level concepts to talk
about. In this example, we group together a number of AWS resources and
allow you to manage them together.


## What

In this example we'll setup 3 separate groups, each with 2 instances and 1
security group. Because each group is nearly the same (apart from the
name), we'll create our own type in Puppet, and then apply that 3 times.

This is a good example of how to use Puppet to avoid repetitive effort
and to create your own abstractions that fit your organization. We're
able to create each group with the following one-liner:

~~~puppet
somegroup { 'test-1': ami => 'ami-67a60d7a', region => 'sa-east-1' }
~~~

## How

Puppet [defined types](https://docs.puppetlabs.com/learning/definedtypes.html) are an
important part of the Puppet language, and when applied to the AWS
module allow for creating reusable stacks of infrastructure. Maybe you
want to create a type for an application stack, making it easy to add
more capacity. Or, maybe you want to describe an entire environment, then
duplicate it for development, staging, and production.

To run our example, with the AWS module installed as described in the README, from this
directory run:

    puppet apply init.pp --test


You can observe these resources using the AWS console or the `puppet resource` CLI, for example:

    puppet resource ec2_securitygroup test-1-sg

This should create the 6 instances and 3 security groups. You can delete them
with the destroy manifest when done.

    puppet apply destroy.pp --test


## Discussion

Defined types are one of the core building blocks of the Puppet
language. By using defined types you can avoid repetition
and create more domain specific instances and security groups.
