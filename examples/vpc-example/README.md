# AWS VPC

A virtual private cloud (VPC) is a virtual network that closely
resembles a traditional network that you'd operate in your own data
center. The AWS Puppet module allows for describing the various moving
parts of VPC in the Puppet DSL. This can be useful for creating and
sharing duplicate environments or alternatively as part of an audit
mechanism to ensure your VPC configuration is as intended.

## What

For this example we're going to create a VPC, a subnet, a route table,
and an internet gateway. This broadly follows the [getting started
example](http://docs.aws.amazon.com/AmazonVPC/latest/GettingStartedGuide/Wizard.html)
from the official Amazon documentation.

As a separate example we'll also look at managing a VPN connection to
AWS from your internal infrastructure.

## How

With the module installed as described in the README, from this
directory run:

    puppet apply init.pp --test

This should create the resources discussed above in the AWS example.
Once complete you should be able to observe the VPC and associated
resources via the AWS console as shown in the example. Alternatively, you
can use the puppet resource CLI to show resources.

    > puppet resource ec2_vpc sample-vpc
    ec2_vpc { 'sample-vpc':
      ensure           => 'present',
      cidr_block       => '10.0.0.0/16',
      instance_tenancy => 'default',
      region           => 'sa-east-1',
    }


Once finished you can delete the created resources with the bundled
manifest like so:

    puppet apply destroy.pp --test

The module also supports resources for the AWS VPN, including for VPN
gateways and customer gateways. The following example will create the
relevant resources, but for a working VPN connection you would need to
provide the BGP ASN and IP address of your VPN gateway. To demonstate
the manifests, run:

    puppet apply vpn.pp --test

You can see these created via the console or the puppet resource
commands. When finished you can delete the created resources with:

    puppet apply vpn_destroy.pp --test


## Discussion

VPC is complex and contains a large number of moving parts.
Currently the module has some support for the following:

* VPC
* DHCP option sets
* Subnets
* Route tables
* Internet gateways
* VPN gateways
* Customer gateways
* VPN

We would love to see examples of common VPC setups described using the
Puppet DSL, so please do submit additional examples as pull requests.
