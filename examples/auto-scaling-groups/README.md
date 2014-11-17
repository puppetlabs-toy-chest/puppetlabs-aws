# Autscaling Support

This example demonstrates managing a higher level infrastructure
component - auto scaling groups.

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
with the `puppet resource` commands when done.

   puppet resource ec2_securitygroup test-sg region=sa-east-1 ensure=absent
   puppet resource ec2_launchconfiguration test-lc region=sa-east-1 ensure=absent
   puppet resource ec2_autoscalinggroup test-asg region=sa-east-1 ensure=absent
   puppet resource ec2_scalingpolicy scaleout region=sa-east-1 ensure=absent
   puppet resource ec2_scalingpolicy scalein region=sa-east-1 ensure=absent
   puppet resource cloudwatch_alarm AddCapacity region=sa-east-1 ensure=absent
   puppet resource cloudwatch_alarm RemoveCapacity region=sa-east-1 ensure=absent


## Discussion

The instances managed by the auto scaling group is not directly
accessible via `puppet resource`. This is by design. However you can
check on the number of instances currently managed by a group with:

   puppet resource ec2_autoscalinggroup test-asg
