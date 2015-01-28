# Autoscaling Support

This example demonstrates managing a higher level infrastructure
component - auto scaling groups. It roughly follows [this
example](http://docs.aws.amazon.com/AutoScaling/latest/DeveloperGuide/policy-creating-cli.html)
from Amazon.


## What

In this example we'll setup:

* A security group
* A launch configuration
* An auto scaling group
* Two scaling policies
* Two CloudWatch alarms tied to the policies

This provides a fully working autoscaling group setup that will
autoscale based on increasing or decreasing load on the instances.

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

The instances managed by the auto scaling group is not directly
accessible via `puppet resource`. This is by design. However you can
check on the number of instances currently managed by a group with:

   puppet resource ec2_autoscalinggroup test-asg
