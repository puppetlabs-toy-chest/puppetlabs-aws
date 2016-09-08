# Setting IAM Permissions for the Module

[IAM](http://aws.amazon.com/iam/) is the Identify and Access Management
component for AWS. It provides one way of restricting access to certain
API calls for a given user. The following shows the permissions
required for the currently supported resources in the AWS Puppet module.

## What

It is advisable to have a good understanding of IAM before commencing. A
good starting point is the [IAM user guide](http://docs.aws.amazon.com/IAM/latest/UserGuide/IAM_Introduction.html).

The following JSON profile grants the permissions required to use
all of the resources currently supported.

## How

Upload the following profile to your IAM account. It is included
for clarity below, but you can download the [raw JSON
file](profile.json) too.

Note that as the number of resources the module supports grows we will
add to this profile.

~~~json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:DescribeRegions",
        "ec2:DescribeInstances",
        "ec2:RunInstances",
        "ec2:StartInstances",
        "ec2:StopInstances",
        "ec2:DeleteTags",
        "ec2:CreateTags",
        "ec2:TerminateInstances",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:CreateLoadBalancer",
        "elasticloadbalancing:DescribeTags",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "elasticloadbalancing:DeleteLoadBalancer",
        "ec2:DescribeSecurityGroups",
        "ec2:CreateSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:DeleteSecurityGroup",
        "ec2:DescribeVpcs",
        "ec2:CreateVpc",
        "ec2:DeleteVpc",
        "ec2:DescribeDhcpOptions",
        "ec2:CreateDhcpOptions",
        "ec2:DeleteDhcp_options",
        "ec2:DescribeCustomerGateways",
        "ec2:CreateCustomerGateway",
        "ec2:DeleteCustomerGateway",
        "ec2:DescribeInternetGateways",
        "ec2:CreateInternetGateway",
        "ec2:AttachInternetGateway",
        "ec2:DeleteInternetGateway",
        "ec2:DetachInternetGateway",
        "ec2:DescribeRouteTables",
        "ec2:CreateRouteTable",
        "ec2:DeleteRouteTable",
        "ec2:CreateRoute",
        "ec2:DescribeSubnets",
        "ec2:CreateSubnet",
        "ec2:DeleteSubnet",
        "ec2:AssociateRouteTable",
        "ec2:DescribeVpnConnections",
        "ec2:CreateVpnConnection",
        "ec2:DeleteVpnConnection",
        "ec2:CreateVpnConnectionRoute",
        "ec2:DescribeVpnGateways",
        "ec2:CreateVpnGateway",
        "ec2:AttachVpnGateway",
        "ec2:DetachVpnGateway",
        "ec2:DeleteVpnGateway",
        "ec2:CreateTags",
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:CreateAutoScalingGroup",
        "autoscaling:UpdateAutoScalingGroup",
        "autoscaling:DeleteAutoScalingGroup",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:CreateLaunchConfiguration",
        "autoscaling:DeleteLaunchConfiguration",
        "autoscaling:DescribePolicies",
        "autoscaling:PutScalingPolicy",
        "autoscaling:DeletePolicy",
        "cloudwatch:DescribeAlarms",
        "cloudwatch:PutMetricAlarm",
        "cloudwatch:DeleteAlarms",
        "route53:ListResourceRecordSets",
        "route53:ListHostedZones",
        "route53:ChangeResourceRecordSets",
        "route53:CreateHostedZone",
        "route53:DeleteHostedZone",
        "rds:CreateDBInstance",
        "rds:ModifyDBInstance",
        "rds:DeleteDBInstance",
        "rds:DescribeDBInstances",
        "rds:AuthorizeDBSecurityGroupIngress",
        "rds:DescribeDBSecurityGroups",
        "rds:CreateDBSecurityGroup",
        "rds:DeleteDBSecurityGroup",
        "rds:DescribeDBParameterGroups",
        "sqs:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
~~~

## Discussion

Given the large number of permissions required by all of the different
resources in the module it might be wise to provide some further
restrictions in conditions. A good exmaple of this id locking
requests down to a specific IP range like so:

~~~json
{
  "Version": "2015-02-13",
  "Statement": [
    {
      "Sid": "Stmt123",
      "Action": [
        "ec2:RunInstances",
        "ec2:DescribeInstances",
        "ec2:CreateTags",
        ...
      ],
      "Effect": "Allow",
      "Resource": "*",
      "Condition": {
        "NotIpAddress": {
          "aws:SourceIp": ["192.0.2.0/24", "203.0.113.0/24"]
        }
      }
    }
  ]
}
~~~
