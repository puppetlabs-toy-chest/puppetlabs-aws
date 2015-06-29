# YAML Definition Example

This example demonstrates a simple approach to definining an
infrastructure stack in the YAML data format, and then using
[Hiera](https://projects.puppetlabs.com/projects/hiera) to create the
Puppet resources.

## What

For this example we're just creating a single instance and security
group, using AMI and region details stored in the YAML file at
`hieradata/common.yaml`.

~~~
                        +------------------------------+
                        | +--------------------------+ |
                        | |                          | |
 create-resources-group | | create-resources-example | |
                        | |                          | |
                        | +--------------------------+ |
                        +------------------------------+
~~~

Feel free to change the details in the YAML file to describe additional
instances or security groups.

## How

With the module installed as described in the README, from this
directory run:

    puppet apply init.pp --test --hiera_config hiera.yaml


This should create an instance and security group. You can delete them
with the `puppet resource` commands when done.

	puppet resource ec2_instance create-resources-example region=us-west-1 ensure=absent
	puppet resource ec2_securitygroup create-resources-group region=us-west-1 ensure=absent


## Discussion

This example uses explicit calls to the Hiera function in the manifests.
In your own manifests you could use [data
binding](https://ask.puppetlabs.com/question/117/how-can-i-use-data-bindings-in-puppet-3/)
and parameterized classes to achieve the same ends.
