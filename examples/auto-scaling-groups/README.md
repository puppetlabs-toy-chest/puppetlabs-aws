# Autoscaling Support

This example demonstrates managing a higher level infrastructure
component - auto scaling groups. It roughly follows [this example](http://docs.aws.amazon.com/AutoScaling/latest/DeveloperGuide/policy-creating-cli.html)
from Amazon.


## What

In this example we'll setup:

* A security group
* A launch configuration
* An auto scaling group
* Two scaling policies
* Two CloudWatch alarms tied to the policies

This provides a fully working auto scaling group setup that will
auto scale based on increasing or decreasing load on the instances.

## How

With the module installed as described in the README, from this
directory run:

    puppet apply init.pp --test


This should create the AWS resources. You can delete them
with the destroy manifest when done.

    puppet apply destroy.pp --test

Note that this will shut down any instances launched by the auto scaling
group. Once the instances are terminated you can remove the accompanying
security group with:

	puppet resource ec2_securitygroup test-sg region=sa-east-1 ensure=absent


## Discussion

The instances managed by the auto scaling group are not directly
accessible via `puppet resource`. This is by design. However, you can
check on the number of instances currently managed by a group with:

	puppet resource ec2_autoscalinggroup test-asg

The auto scaling resources also support launching in a VPC. First,
provide the name of a subnet to attach the auto scaling group to:

~~~puppet
ec2_autoscalinggroup { 'test-asg':
  ...
  subnets => 'subnet-name',
}
~~~

Note that the security groups attached to the launch configuration must
be associated with the same subnet. In cases where multiple security
groups exist with the same name, typically the case for the default
security group, you can provide a hint to the launch configuration like
so:

~~~
ec2_launchconfiguration { 'test-lc':
  security_groups => ['default'],
  vpc             => 'subnet-acceptance',
}
~~~

