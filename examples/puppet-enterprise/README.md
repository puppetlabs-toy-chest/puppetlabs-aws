# Puppet Enterprise

[Puppet Enterprise](http://puppetlabs.com/puppet/puppet-enterprise) is free for up to 10 nodes,
and a great way of getting started with Puppet. This example brings up a Puppet Master and two
agents, one Windows and one Linux based.

## What

~~~
                                      443
                                       +
                                       |
                                       |
                   +-------------------|-------------------+
                   |          +--------v--------+          |
                   |          |                 |          |
                   |          |  puppet-master  |          |
                   |          |                 |          |
 puppet-enterprise |          +-----------------+          |
                   | +----------------+ +----------------+ |
                   | |                | |                | |
                   | |  puppet-agent  | | puppet-windows | |
                   | |                | |                | |
                   | +----------------+ +----------------+ |
                   +---------------------------------------+

~~~


## How

This example is in two parts, first we'll bring up the Puppet Master. After
making a quick configuration change, we'll bring up two Puppet agents.

With the module installed as described in the README, from this
directory run:

    puppet apply pe_master.pp --test --templatedir templates

This will bring up the master. Please note that this could take up to 10
minutes.

We now need to modify the `pe_agent.pp` manifest so it points at the newly created
master. Open up `pe_agent.pp` and change the line:

    $pe_master_hostname = 'ip-your-ip-here.us-west-2.compute.internal'

You can find the IP address under _Private DNS_ in the AWS web console.
Alternatively, you can use the `puppet resource` commands:

    puppet resource ec2_instance puppet-master

This should return a Puppet resource, including the public and private
IP and DNS details.

Finally, run the following:

    puppet apply pe_agent.pp --test --templatedir templates

Now let's login to your new Puppet Enterprise console. Retrieve the _Public IP_ address
of the `puppet-master` instance from the AWS console or using `puppet resource`, then visit:

    https://your-public-ip-address

You can login with the username `admin` and the password `puppetlabs`,
or you can change these in the `pe_agent.pp` file mentioned above.

Note the https part. Because we're using a temporary IP address here you'll likely
get a certificate error from your browser, ignore this for now.

You can learn more about using Puppet Enterprise from the comprehensive
[user guide](https://docs.puppetlabs.com/pe/latest/)


## Discussion

This example demonstrates the power of using the AWS module but still has a few rough
edges, specifically:

* You need to run the manifests twice, first to create the master and then to
  create the agents.
* All certificates from agents are automatically signed by the master.

All of these are solvable, one approach being to utilize Amazon's VPC service
and to use the policy based autosigning API in Puppet. We'll likely build on
this example as we develop the module.
