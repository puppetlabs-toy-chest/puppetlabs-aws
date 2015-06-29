# Hiera Example

This example demonstrates a simple approach to pulling
common data out of your manifests and into
[Hiera](https://projects.puppetlabs.com/projects/hiera).

## What

For this example we're creating a single instance and security
group, using AMI and region details stored in the Hiera YAML file at
`hieradata/common.yaml`.

```
             +-------------+
             | +---------+ |
             | |         | |
 hiera-test  | | hiera-1 | |
             | |         | |
             | +---------+ |
             +-------------+
```

Feel free to change the details in the YAML file to other AMIs and
regions.

## How

With the module installed as described in the README, from this
directory run:

    puppet apply init.pp --test --hiera_config hiera.yaml


This should create an instance and security group. You can delete them
with the `puppet resource` commands when done.

	puppet resource ec2_instance hiera-1 region=us-west-1 ensure=absent
	puppet resource ec2_securitygroup hiera-test region=us-west-1 ensure=absent


## Discussion

This example uses explicit calls to the Hiera function in the manifests.
In your own manifests you could use [data
binding](https://ask.puppetlabs.com/question/117/how-can-i-use-data-bindings-in-puppet-3/)
and parameterized classes to achieve the same ends.
