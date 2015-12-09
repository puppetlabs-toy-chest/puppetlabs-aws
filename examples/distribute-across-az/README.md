# Distributing instances across availability zones

This example shows a method of balancing instances across availability zones using the latest Puppet language features.

## What

First take a look at the code in [init.pp](init.pp). It's relatively advanced but contains lots of comments to explain what's happening. Once you're happy (and have the AWS module installed) you can run:

    puppet apply init.pp --parser future --test

This should:

* Launch 2 instances called lb-1, lb-2, 1 in each of the availability zones in sa-east-1
* Launch 5 instances, called app-1, app-2, etc. distributed across the two availability zones

You can now modify the variables at the top of the Puppet manifest which control the number of instances launched. If you increase the number `$number_of_app_servers` more instances will be created and distributed between the availablility zones. If you reduce the number, instances will be terminated.

Once you're finished you can shut down all instances with the following.

    puppet apply destroy.pp --test

Note that if you launched in a different region or launched more than 10 instances you will need to modify that manifest.

## How

This examples shows the power of the new [Puppet language parser](https://docs.puppetlabs.com/puppet/latest/reference/experiments_future.html) combined with some of the functions (like `range`, `flatten`, and `validate_*`) from the [Puppet stdlib](https://forge.puppetlabs.com/puppetlabs/stdlib).

This example could be wrapped in a defined type, allowing you to describe a cluster at a high level and then instantiate multiple copies, potentially with different limits or in different regions.


## Thanks

Thanks to [Daniel Dreier](https://github.com/danieldreier) who first came up with the basics of this idea.
