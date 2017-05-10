[![Puppet
Forge](http://img.shields.io/puppetforge/v/puppetlabs/aws.svg)](https://forge.puppetlabs.com/puppetlabs/aws)
[![Build
Status](https://travis-ci.org/puppetlabs/puppetlabs-aws.svg?branch=master)](https://travis-ci.org/puppetlabs/puppetlabs-aws)

#### Table of Contents

1. [Overview](#overview)
2. [Description - What the module does and why it is useful](#description)
3. [Setup](#setup)
  * [Requirements](#requirements)
  * [Installing the aws module](#installing-the-aws-module)
4. [Usage - Configuration options and additional functionality](#usage)
  * [Creating resources](#creating-resources)
  * [Creating a stack](#creating-a-stack)
  * [Managing resources from the command line](#managing-resources-from-the-command-line)
  * [Managing AWS infrastructure](#managing-aws-infrastructure)
5. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
  * [Types](#types)
  * [Parameters](#parameters)
6. [Limitations - OS compatibility, etc.](#limitations)

## Overview

The aws module manages Amazon Web Services (AWS) resources to build out cloud infrastructure.

## Description

Amazon Web Services exposes a powerful API for creating and managing its infrastructure as a service platform. The aws module allows you to drive that API using Puppet code. 

In the simplest case, this allows you to create new EC2 instances from Puppet code. More importantly, it allows you to describe your entire AWS infrastructure and to model the relationships between different components.

## Setup

### Requirements

* Puppet 4.7 or greater
* Ruby 1.9 or greater
* Amazon AWS Ruby SDK (available as a gem)
* Retries gem

### Installing the aws module

1. Install the retries gem and the Amazon AWS Ruby SDK gem, using the same Ruby used by Puppet. For Puppet 4.x and beyond, install the gems with this command:

  '/opt/puppetlabs/puppet/bin/gem install aws-sdk-core retries'

2. Set these environment variables for your AWS access credentials:

  ```bash
  export AWS_ACCESS_KEY_ID=your_access_key_id
  export AWS_SECRET_ACCESS_KEY=your_secret_access_key
  ```

  Alternatively, you can place the credentials in a file at '~/.aws/credentials' based on the following template:

  ```bash
 [default]
  aws_access_key_id = your_access_key_id
  aws_secret_access_key = your_secret_access_key
  ```

  If you have Puppet running on AWS, and you're running the module examples, you can instead use [IAM](http://aws.amazon.com/iam/). To do this, assign the correct role to the instance from which you're running the examples. For a sample profile with all the required permissions, see the [IAM profile example](https://github.com/puppetlabs/puppetlabs-aws/tree/master/examples/iam-profile/).

3. Finally, install the module with:

  ```bash
puppet module install puppetlabs-aws
  ```

#### A note on regions

By default the module looks through all regions in AWS when determining if something is available. This can be a little slow. If you know what you're doing you can speed things up by targeting a single region using an environment variable.

```bash
export AWS_REGION=eu-west-1
````

#### A note on proxies

By default the module accesses the AWS API directly, but if you're in an environment that doesn't have direct access you can provide a proxy setting for all traffic like so:

```bash
export PUPPET_AWS_PROXY=http://localhost:8888
```

#### Configuring the aws module using an ini file

The AWS region and HTTP proxy can be provided in a file called 'puppetlabs_aws_configuration.ini' in the Puppet confdir ('$settings::confdir') using this format:

```ini
    [default]
      region = us-east-1
      http_proxy = http://proxy.example.com:80
```

## Usage

### Creating resources

You can set up EC2 instances with a variety of AWS features, as well as a VPC, security group, and load balancer.

**Setup a VPC:**

``` puppet
ec2_vpc { 'name-of-vpc':
  ensure     => present,
  region     => 'us-east-1',
  cidr_block => '10.0.0.0/24',
  tags       => {
    tag_name => 'value',
  },
}
```

**Setup a subnet:**

``` puppet
ec2_vpc_subnet { 'name-of-subnet':
  ensure                  => present,
  region                  => 'us-east-1',
  cidr_block              => '10.0.0.0/24',
  availability_zone       => 'us-east-1a',
  map_public_ip_on_launch => true,
  vpc                     => 'name-of-vpc,
  tags                    => {
    tag_name => 'value',
  },
}
```

**Setup a security group:**

``` puppet
ec2_securitygroup { 'name-of-security-group':
  ensure      => present,
  region      => 'us-east-1',
  vpc         => 'name-of-vpc',
  description => 'a description of the group',
  ingress     => [{
    protocol  => 'tcp',
    port      => 22,
    cidr      => '0.0.0.0/0',
  }],
  tags        => {
    tag_name  => 'value',
  },
}
```

**Setup an instance:**

``` puppet
ec2_instance { 'name-of-instance':
  ensure            => running,
  region            => 'us-east-1',
  availability_zone => 'us-east-1a',
  image_id          => 'ami-123456', # you need to select your own AMI
  instance_type     => 't2.micro',
  key_name          => 'name-of-existing-key',
  subnet            => 'name-of-subnet',
  security_groups   => ['name-of-security-group'],
  tags              => {
    tag_name => 'value',
  },
}
```

**Setup a load balancer:**

``` puppet
elb_loadbalancer { 'name-of-load-balancer':
  ensure                  => present,
  region                  => 'us-east-1',
  availability_zones      => ['us-east-1a', 'us-east-1b'],
  instances               => ['name-of-instance', 'another-instance'],
  security_groups         => ['name-of-security-group'],
  listeners               => [
    {
      protocol              => 'HTTP',
      load_balancer_port    => 80,
      instance_protocol     => 'HTTP',
      instance_port         => 80,
    },{
      protocol              => 'HTTPS',
      load_balancer_port    => 443,
      instance_protocol     => 'HTTPS',
      instance_port         => 8080,
      ssl_certificate_id    => 'arn:aws:iam::123456789000:server-certificate/yourcert.com',
      policies              =>  [
        {
          'policy_type'       => 'SSLNegotiationPolicyType',
          'policy_attributes' => {
            'Protocol-TLSv1.1' => false,
            'Protocol-TLSv1.2' => true,
          }
        }
      ]
    }
  ],
  health_check            => {
    'healthy_threshold'   => '10',
    'interval'            => '30',
    'target'              => 'HTTP:80/health_check',
    'timeout'             => '5',
    'unhealthy_threshold' => '2'
  },
  tags                    => {
    tag_name              => 'value',
  },
}
```

To destroy any of these resources, set `ensure => absent`.

### Creating a stack

Let's create a simple stack, with a load balancer, instances, and security groups.

```
                          WWW
                           +
                           |
          +----------------|-----------------+
          |     +----------v-----------+     |
    lb-sg |     |         lb-1         |     |
          |     +----+------------+----+     |
          +----------|------------|----------+
          +----------|------------|----------+
          |     +----v----+  +----v----+     |
          |     |         |  |         |     |
   web-sg |     |  web-1  |  |  web-2  |     |
          |     |         |  |         |     |
          |     +----+----+  +----+----+     |
          +----------|------------|----------+
          +----------|------------|----------+
          |     +----v----+       |          |
          |     |         |       |          |
    db-sg |     |  db-1   <-------+          |
          |     |         |                  |
          |     +---------+                  |
          +----------------------------------+
```

We've supplied code for the creation of this stack in this module's tests directory. To run this code with Puppet apply, run:

``` bash
puppet apply tests/create.pp --test
```

If you want to try this out from this directory without installing the module, run the following:

```bash
puppet apply tests/create.pp --modulepath ../ --test
```

To destroy the resources created by the above, run the following:

```bash
puppet apply tests/destroy.pp --test
```

### Managing resources from the command line

The module has basic `puppet resource` support, so you can manage AWS resources from the command line.

For example, the following command lists all the security groups:

```bash
puppet resource ec2_securitygroup
```

You can also create new resources:

``` bash
puppet resource ec2_securitygroup test-group ensure=present description="test description" region=us-east-1
```

and then destroy them, all from the command line:

``` bash
puppet resource ec2_securitygroup test-group ensure=absent region=sa-east-1
```


### Managing AWS infrastructure

You can use the aws module to audit AWS resources, launch autoscaling groups in VPC, perform unit testing, and more. The [examples](https://github.com/puppetlabs/puppetlabs-aws/tree/master/examples) directory in the module contains a variety of usage examples that should give you an idea of what's possible:

* [Puppet Enterprise](https://github.com/puppetlabs/puppetlabs-aws/tree/master/examples/puppet-enterprise/): Start up a small Puppet Enterprise cluster using the AWS module.
* [Managing DNS](https://github.com/puppetlabs/puppetlabs-aws/tree/master/examples/manage-dns/): Manage DNS records in Amazon Route53 using Puppet.
* [Data Driven Manifests](https://github.com/puppetlabs/puppetlabs-aws/tree/master/examples/data-driven-manifests/): Automatically generate resources based on a data structure.
* [Hiera Example](https://github.com/puppetlabs/puppetlabs-aws/tree/master/examples/hiera-example/): Store common information like region or AMI id in Hiera.
* [Infrastructure as YAML](https://github.com/puppetlabs/puppetlabs-aws/tree/master/examples/yaml-infrastructure-definition/): Describe an entire infrastructure stack in YAML, and use `create_resources` and Hiera to build your infrastructure.
* [Auditing Resources](https://github.com/puppetlabs/puppetlabs-aws/tree/master/examples/audit-security-groups/): Audit AWS resource changes and work alongside other tools.
* [Unit Testing](https://github.com/puppetlabs/puppetlabs-aws/tree/master/examples/unit-testing): Test your AWS code with Puppet testing tools like rspec-puppet.
* [Virtual Private Cloud](https://github.com/puppetlabs/puppetlabs-aws/tree/master/examples/vpc-example): Use the Puppet DSL to manage a AWS VPC environment.
* [Using IAM permissions](https://github.com/puppetlabs/puppetlabs-aws/tree/master/examples/iam-profile): Control the API permissions required by the module with an IAM profile.
* [Elastic IP Addresses](https://github.com/puppetlabs/puppetlabs-aws/tree/master/examples/elastic-ip-addresses/): Attach existing elastic IP addresses to instances managed by Puppet.
* [Create your own abstractions](https://github.com/puppetlabs/puppetlabs-aws/tree/master/examples/create-your-own-abstractions/): Use Puppet's defined types to better model your own infrastructure.
* [Distribute instances across availability zones](https://github.com/puppetlabs/puppetlabs-aws/tree/master/examples/distribute-across-az/): Use the future parser and stdlib functions to launch instances balanced across different availability zones.

## Reference

### Types

* `cloudformation_stack`: Create, update, or destroy a CloudFormation Stack.
* `cloudfront_distribution`: Sets up a CloudFront distribution.
* `ec2_instance`: Sets up an EC2 instance.
* `ec2_securitygroup`: Sets up an EC2 security group.
* `ec2_volume`: Sets up an EC2 EBS volume.
* `elb_loadbalancer`: Sets up an ELB load balancer.
* `cloudwatch_alarm`: Sets up a Cloudwatch Alarm.
* `ec2_autoscalinggroup`: Sets up an EC2 auto scaling group.
* `ec2_elastic_ip`: Sets up an Elastic IP and its association.
* `ec2_launchconfiguration`: Sets up an EC2 launch configuration to provide autoscaling support.
* `ec2_scalingpolicy`: Sets up an EC2 scaling policy.
* `ec2_vpc`: Sets up an AWS VPC.
* `ec2_vpc_customer_gateway`: Sets up an AWS VPC customer gateway.
* `ec2_vpc_dhcp_options`: Sets a DHCP option AWS VPC.
* `ec2_vpc_internet_gateway`: Sets up an EC2 VPC Internet Gateway.
* `ec2_vpc_routetable`: Sets up a VPC route table.
* `ec2_vpc_subnet`: Sets up a VPC subnet.
* `ec2_vpc_vpn`: Sets up an AWS Virtual Private Network.
* `ec2_vpc_vpn_gateway`: Sets up a VPN gateway.
* `ecs_cluster`: Manage an Ec2 Container Service cluster.
* `ecs_service`: Manage an Ec2 Container Service service.
* `ecs_task_definition`: Manage an Ec2 Container Service task definition.
* `iam_group`: Manage IAM groups and their membership.
* `iam_instance_profile`: Manage IAM instance profiles.
* `iam_policy`: Manage an IAM 'managed' policy.
* `iam_policy_attachment`: Manage an IAM 'managed' policy attachments.
* `iam_role`: Manage an IAM role.
* `iam_user`: Manage IAM users.
* `kms`: Manage KMS keys and their policies.
* `rds_db_parameter_group`: Allows read access to DB Parameter Groups.
* `rds_db_securitygroup`: Sets up an RDS DB Security Group.
* `rds_db_subnet_group`: Sets up an RDS DB Subnet Group.
* `rds_instance`: Sets up an RDS Database instance.
* `route53_a_record`: Sets up a Route53 DNS record.
* `route53_aaaa_record`: Sets up a Route53 DNS AAAA record.
* `route53_cname_record`: Sets up a Route53 CNAME record.
* `route53_mx_record`: Sets up a Route53 MX record.
* `route53_ns_record`: Sets up a Route53 DNS record.
* `route53_ptr_record`: Sets up a Route53 PTR record.
* `route53_spf_record`: Sets up a Route53 SPF record.
* `route53_srv_record`: Sets up a Route53 SRV record.
* `route53_txt_record`: Sets up a Route53 TXT record.
* `route53_zone`: Sets up a Route53 DNS zone.
* `s3_bucket`: Sets up an S3 bucket.
* `sqs_queue`: Sets up an SQS queue.

### Parameters

#### Type: cloudformation_stack

##### `capabilities`

Optional. 

The list of stack capabilities.

Valid values are: 'CAPABILITY_IAM', 'CAPABILITY_NAMED_IAM', an empty list, or unspecified.

##### `change_set_id`

Read-only.

Unique identifier of the stack.

##### `creation_time`

Read-only.

The time at which the stack was created.

##### `description`

Read-only.

A user-defined description found in the cloud formation template associated with the stack.

##### `disable_rollback`

Optional. 

Whether to disable rollback on stack creation failures. 

Valid values are: `true`, `false`.

##### `ensure`

Required. 

The ensure value for the stack.

'present' will create the stack but not apply updates.

'updated' will create or apply any updates to the stack.

'absent' will delete the stack.

Valid values are: 'present', 'updated', 'absent'.

##### `id`

Read-only.

The unique ID of the stack.

##### `last_updated_time`
Read-only.

The time the stack was last updated.

##### `name`

Required.
 
The name of the stack.

##### `notification_arns`

Optional.
 
List of SNS topic ARNs to which stack related events are published.

##### `on_failure`

Optional. 

Determines what action will be taken if stack creation fails.

You can specify either 'on_failure' or 'disable_rollback', but not both.

Valid values are: 'DO_NOTHING', 'ROLLBACK', 'DELETE'.

##### `outputs`

Read-only.

A hash of stack outputs.

##### `parameters`

Optional.

A hash of input parameters.

##### `policy_body`

Optional. 

Structure containing the stack policy body. 

For more information, go to prevent updates to Stack Resources in the AWS CloudFormation User Guide. 

You can specify either the `policy_body` or the `policy_url` parameter, but not both.

##### `policy_url`

Optional.

Location of a file containing the stack policy. The URL must point to a policy (maximum size: 16 KB) located in an S3 bucket in the same region as the stack. 

You can specify either the `policy_body` or the `policy_url` parameter, but not both.

##### `region`

Required.
 
The region in which to launch the stack.

##### `resource_types`

Optional.

The list of resource types that you have permissions to work with for this stack.

##### `role_arn`

Optional. 

The Amazon Resource Name (ARN) of an AWS Identity and Access Management (IAM) role that is associated with the stack.

##### `status`

Read-only.

The status of the stack.

Valid values are: 'CREATE_IN_PROGRESS', 'CREATE_FAILED', 'CREATE_COMPLETE', 'ROLLBACK_IN_PROGRESS', 'ROLLBACK_FAILED', 'ROLLBACK_COMPLETE', 'DELETE_IN_PROGRESS', 'DELETE_FAILED', 'DELETE_COMPLETE', 'UPDATE_IN_PROGRESS', 'UPDATE_COMPLETE_CLEANUP_IN_PROGRESS', 'UPDATE_COMPLETE', 'UPDATE_ROLLBACK_IN_PROGRESS', 'UPDATE_ROLLBACK_FAILED', 'UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS', 'UPDATE_ROLLBACK_COMPLETE', 'REVIEW_IN_PROGRESS'.

##### `tags`

Optional.

The tags for the instance.

##### `template_body`

Optional. 

Structure containing the template body with a minimum length of 1 byte and a maximum length of 51,200 bytes. 

For more information, go to Template Anatomy in the AWS CloudFormation User Guide.

##### `template_url`

Optional. 

Location of file containing the template body. The URL must point to a template (max size: 460,800 bytes) that is located in an Amazon S3 bucket. 

For more information, go to the Template Anatomy in the AWS CloudFormation User Guide.

##### `timeout_in_minutes`

Optional. 

The amount of time within which stack creation should complete.

#### Type: cloudfront_distribution

##### `ensure`

Specifies the basic state of the resource. 

Valid values are: 'present', 'absent'.

##### `arn`

Read-only.

The AWS-generated ARN of the distribution.

##### `id`

Read-only.

The AWS-generated ID of the distribution.

##### `status`

Read-only.

The AWS-reported status of the distribution.

##### `comment`

Optional.

The comment on the distribution.

##### `enabled`

Optional.

Whether the distribution is enabled.

##### `price_class`

Optional. 

The price class of the distribution.

Valid values are: 'all, 100, 200.

Default value: all.

Accepts one value only.

##### `origins`

Required.
 
An array of at least one origin. Each origin is a hash with the following keys:

* `type` — 

*Required.* 

The origin type. 'S3' is not yet supported.

Valid values are: 'custom'.

* `id` — 

*Required.* 

The origin ID. Must be unique within the distribution. Used to identify the origin for caching rules.
* `domain_name` — 

*Required.* 

The origin domain name.

* `path` —

*Optional.* 

The origin path. Defaults to no path.

* `http_port` — 

*Required for custom origins.* 

The port the origin is listening on for HTTP connections.

* `https_port` — 

*Required for custom origins.* 

The port the origin is listening on for HTTPS connections.

* `protocol_policy` — 

*Required for custom origins.* 

Which protocols the origin accepts.

Accepts only one value.

Valid values: 'http-only', 'https-only', 'match-viewer'.

* `protocols` — 

*Required for custom origins.* 

An array of SSL and TLS versions the origin accepts. 

Accepts at least one value.

Valid values: 'SSLv3', 'TLSv1', 'TLSv1.1', 'TLSv1.2'.

##### `tags`

Optional.
 
The tags for the distribution. 

Accepts a key => value hash of tags. 

Excludes 'Name' tag.

#### Type: ec2_instance

##### `ensure`

Specifies the basic state of the resource. 

Valid values are: 'present', 'absent', 'running', 'stopped'.

##### `name`

Required.
 
The name of the instance. This is the value of the AWS Name tag.

##### `security_groups`

Optional. 

The security groups with which to associate the instance. 

Accepts an array of security group names.

##### `tags`

Optional. 

The tags for the instance. 

Accepts a key => value hash of tags.

##### `user_data`

Optional. 

User data script to execute on new instance. 

This parameter is set at creation only; it is not affected by updates.

##### `key_name`

The name of the key pair associated with this instance. This must be an existing key pair already uploaded to the region in which you're launching the instance.

This parameter is set at creation only; it is not affected by updates.

##### `monitoring`

Optional. 

Whether or not monitoring is enabled for this instance. 

This parameter is set at creation only; it is not affected by updates. 

Valid values are: `true`, `false`. 

Default value: `false`.

##### `region`

Required.
 
The region in which to launch the instance. 

Valid values are:

See [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

##### `image_id`

Required.
 
The image id to use for the instance. 

This parameter is set at creation only; it is not affected by updates. 

See [Amazon Machine Image (AMI)](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/finding-an-ami.html).

##### `availability_zone`

Optional. 

The availability zone in which to place the instance. 

This parameter is set at creation only; it is not affected by updates. 

Valid values are:
 
See [AWS Regions and Availability Zones](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html).

##### `instance_type`

Required.
 
The type to use for the instance. 

This parameter is set at creation only; it is not affected by updates. 

See [Amazon EC2 Instances](http://aws.amazon.com/ec2/instance-types/) for available types.

##### `tenancy`

Optional. 

Dedicated instances are Amazon EC2 instances that run in a virtual private cloud (VPC) on hardware that's dedicated to a single customer. 

Valid values are: 'dedicated' and 'default'.

Default value: 'default'.

##### `private_ip_address`

Optional. 

The private IP address for the instance. 

This parameter is set at creation only; it is not affected by updates. 

Valid values are:

Valid IPv4 address.

##### `associate_public_ip_address`

Optional. 

Whether to assign a public interface in a VPC. 

This parameter is set at creation only; it is not affected by updates. 

Valid values are: `true`, `false`. 

Default value: `false`.

##### `subnet`

Optional. 

The VPC subnet to attach the instance to. 

This parameter is set at creation only; it is not affected by updates. 

Accepts the name of the subnet; this is the value of the Name tag for the subnet. If you're describing the subnet in Puppet, then this value is the name of the resource.

##### `ebs_optimized`

Optional. 

Whether or not to use optimized storage for the instance.  

This parameter is set at creation only; it is not affected by updates. 

Valid values are: `true`, `false`. 

Default value: `false`.

##### `instance_initiated_shutdown_behavior`

Optional. 

Whether the instance stops or terminates when you initiate shutdown from the instance. 

This parameter is set at creation only; it is not affected by updates. 

Valid values are: 'stop', 'terminate'. 

Default value: 'stop'.

##### `block_devices`

Optional. 

A list of block devices to associate with the instance. 

This parameter is set at creation only; it is not affected by updates. 

Accepts an array of hashes with the 'device name', 'volume size', 'delete on termination flag', and 'volume type' specified:

``` puppet
block_devices => [
  {
    device_name           => '/dev/sda1',
    volume_size           => 8,
    delete_on_termination => 'true',
    volume_type          => 'gp2',
  }
]
```

``` puppet
block_devices => [
  {
    device_name  => '/dev/sda1',
    snapshot_id => 'snap-29a6ca13',
  }
]
```

##### `instance_id`

Read-only.

The AWS generated id for the instance. 

##### `hypervisor`

Read-only.

The type of hypervisor running the instance.

##### `virtualization_type`

Read-only.

The underlying virtualization of the instance.

##### `public_ip_address`

Read-only.

The public IP address for the instance.

##### `private_dns_name`

Read-only.

The internal DNS name for the instance.

##### `public_dns_name`

Read-only.

The publicly available DNS name for the instance.

##### `kernel_id`

Read-only.

The ID of the kernel in use by the instance.

##### `iam_instance_profile_name`

The user provided name for the IAM profile to associate with the instance.

##### `iam_instance_profile_arn`

The Amazon Resource Name for the associated IAM profile.

##### `interfaces`

Read-only.

The AWS generated interfaces hash for the instance.

#### Type: ec2_securitygroup

##### `name`

Required. 

The name of the security group. This is the value of the AWS Name tag.

##### `region`

Required.
 
The region in which to launch the security group. 

Valid values are: 

See [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

##### `ingress`

Optional. 

Rules for ingress traffic. 

Accepts an array.

##### `id`

Read-only.
 
Unique string enumerated from existing resources uniquely identifying the security group.

##### `tags`

Optional. 

The tags for the security group. 

Accepts a key => value hash of tags.

##### `description`

Required.
 
A short description of the group. 

This parameter is set at creation only; it is not affected by updates.

##### `vpc`

Optional.

The VPC to which the group should be associated. 

This parameter is set at creation only; it is not affected by updates. 

Accepts the value of the Name tag for the VPC.

#### Type: elb_loadbalancer

##### `name`

Required.
 
The name of the load balancer. This is the value of the AWS Name tag.

##### `region`

Required.
 
The region in which to launch the load balancer. 

Valid values are:
 
See [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

##### `listeners`

Required.
 
The ports and protocols the load balancer listens to.  

Accepts an array of the following values:

  * protocol
  * load_balancer_port
  * instance_protocol
  * instance_port
  * ssl_certificate_id (required if protocol is HTTPS)
  * policy_names (optional array of policy name strings for HTTPS)

##### `health_check`

The configuration for an ELB health check used to determine the health of the back- end instances.  

Accepts a hash with the following keys:

  * healthy_threshold
  * interval
  * target
  * timeout
  * unhealthy_threshold

##### `tags`

Optional.

The tags for the load balancer. 

This parameter is set at creation only; it is not affected by updates. 

Accepts a key => value hash of tags.

##### `subnets`

Optional.

The subnet in which the load balancer should be launched. 

Accepts an array of subnet names, i.e., the Name tags on the subnets. You can only set one of 'availability_zones' or 'subnets'.

##### `security_groups`

Optional.

The security groups to associate with the load balancer (VPC only). 

Accepts an array of security group names, i.e., the Name tag on the security groups.

##### `availability_zones`

Optional.

The availability zones in which to launch the load balancer. 

This parameter is set at creation only; it is not affected by updates. 

Accepts an array on availability zone codes. 

Valid values are:
 
See [AWS Regions and Availability Zones](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html). You can only set one of 'availability_zones' or 'subnets'.

##### `instances`

Optional.

The instances to associate with the load balancer. 

Valid values are: 

Accepts an array of names, i.e., the Name tag on the instances.

##### `scheme`

Optional.

Whether the load balancer is internal or public facing. 

This parameter is set at creation only; it is not affected by updates. 

Valid values are: 'internal', 'internet-facing'. 

Default value: 'internet-facing' and makes the load balancer publicly available.

#### Type: ec2_volume

##### `name`

Required.

The name of the volume.

##### `region`

Required.
 
The region in which to create the volume. 

Valid values are:

See [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

##### `size`

Conditional.

The size of the EBS volume in GB. if restoring from snapshot this parameter is not required.

##### `iops`

Optional.

Only valid for Provisioned IOPS SSD volumes. The number of I/O operations per second (IOPS) to provision for the volume, with a maximum ratio of 50 IOPS/GiB.

##### `availability_zone`

Required.
 
The availability zones in which to create the volume. 

Accepts an array of availability zone codes. 

Valid values are:
 
See [AWS Regions and Availability Zones](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html).

##### `volume_type`

Required.

The volume type. This can be gp2 for General Purpose SSD, io1 for Provisioned IOPS SSD, st1 for Throughput Optimized HDD, sc1 for Cold HDD, or standard for Magnetic volumes.

##### `encrypted`

Optional.

Specifies whether the volume should be encrypted. Encrypted Amazon EBS volumes may only be attached to instances that support Amazon EBS encryption. Volumes that are created from encrypted snapshots are automatically encrypted. There is no way to create an encrypted volume from an unencrypted snapshot or vice versa.

##### `kms_key_id`

Optional.

The full ARN of the AWS Key Management Service (AWS KMS) customer master key (CMK) to use when creating the encrypted volume. This parameter is only required if you want to use a non-default CMK; if this parameter is not specified, the default CMK for EBS is used.

##### `snapshot_id`

Optional.

The snapshot from which to create the volume.

#### Type: cloudwatch_alarm

##### `name`

Required.
 
The name of the alarm. This is the value of the AWS Name tag.

##### `metric`

Required.

The name of the metric to track.

##### `namespace`

Required.

The namespace of the metric to track.

##### `statistic`

Required.

The statistic to track for the metric.

##### `period`

Required.

The periodicity of the alarm check, i.e., how often the alarm check should run.

##### `evaluation_periods`

Required.

The number of checks to use to confirm the alarm.

##### `threshold`

Required.

The threshold used to trigger the alarm.

##### `comparison_operator`

Required.

The operator to use to test the metric.

##### `region`

Required.

The region in which to launch the instances. 

Valid values are:

See [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

##### `dimensions`

Optional.

The dimensions by which to filter the alarm by. 

For more information about EC2 dimensions, see AWS [Dimensions and Metrics](http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/ec2-metricscollected.html) documentation.

##### `alarm_actions`

Optional.

The actions to trigger when the alarm triggers. 

This parameter is set at creation only; it is not affected by updates. 

This parameter currently supports only named scaling policies.

#### Type: ec2_autoscalinggroup

##### `name`
Required.

The name of the auto scaling group. This is the value of the AWS Name tag.

##### `min_size`

Required.

The minimum number of instances in the group.

##### `max_size`

Required.

The maximum number of instances in the group.

##### `desired_capacity`

Optional.

The number of EC2 instances that should be running in the group. This number must be greater than or equal to the minimum size of the group and less than or equal to the maximum size of the group. 

Default value: `min_size`.

##### `default_cooldown`

Optional.

The amount of time, in seconds, after a scaling activity completes before another scaling activity can start.

##### `health_check_type`

Optional.

The service to use for the health checks. 

Valid values are: 'EC2' and 'ELB'.

##### `health_check_grace_period`

Optional.

The amount of time, in seconds, that Auto Scaling waits before checking the health status of an EC2 instance that has come into service. During this time, any health check failures for the instance are ignored. 

Default value: 300. This parameter is required if you are adding an ELB health check.

##### `new_instances_protected_from_scale_in`

Optional.

Indicates whether newly launched instances are protected from termination by Auto Scaling when scaling in. 

Default value: `true`.

##### `region`

Required.

The region in which to launch the instances. 

Valid values are:

See [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

##### `launch_configuration`

Required.

The name of the launch configuration to use for the group. This is the value of the AWS Name tag.

##### `availability_zones`

Required.

The availability zones in which to launch the instances. 

Accepts an array of availability zone codes. 

Valid values are:

See [AWS Regions and Availability Zones](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html).

##### `load_balancers`

Optional.

A list of load balancer names that should be attached to this autoscaling group.

##### `target_groups`

Optional.

A list of ELBv2 Target Group names that should be attached to this autoscaling group.

##### `subnets`

Optional.

The subnets to associate with the autoscaling group.

##### `termination_policies`

Optional.

A list of termination policies to use when scaling in instances. 

Valid values are:

See [Controlling Which Instances Auto Scaling Terminates During Scale In](http://docs.aws.amazon.com/autoscaling/latest/userguide/as-instance-termination.html).

##### `tags`

Optional.

The tags to assign to the autoscaling group. 

Accepts a key => value hash of tags. The tags are not propagated to launched instances.

#### Type: ec2_elastic_ip

##### `ensure`

Specifies that basic state of the resource. 

Valid values are: 'attached', 'detached'.

##### `name`

Required.

The IP address of the Elastic IP.

Valid values are:

A valid IPv4 address of an already existing elastic IP.

##### `region`

Required.

The region in which the Elastic IP is found. 

Valid values are:

See [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

##### `instance`

Required.

The name of the instance associated with the Elastic IP. This is the value of the AWS Name tag.

#### Type: ec2_launchconfiguration

##### `name`

Required.

The name of the launch configuration. This is the value of the AWS Name tag.

##### `security_groups`

Required.

The security groups to associate with the instances. 

This parameter is set at creation only; it is not affected by updates. 

Accepts an array of security group names, i.e., the Name tags on the security groups.

##### `user_data`

Optional.

User data script to execute on new instances. 

This parameter is set at creation only; it is not affected by updates.

##### `key_name`

Optional.

The name of the key pair associated with this instance. 

This parameter is set at creation only; it is not affected by updates.

##### `region`

Required.

The region in which to launch the instances.

Valid values are:

See [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

##### `instance_type`

Required.

The type to use for the instances. 

This parameter is set at creation only; it is not affected by updates. 

See [Amazon EC2 Instances](http://aws.amazon.com/ec2/instance-types/) for available types.

##### `image_id`

Required.

The image id to use for the instances. 

This parameter is set at creation only; it is not affected by updates. 

See [Amazon Machine Image (AMI)](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/finding-an-ami.html).

##### `block_device_mappings`

Optional.

A list of block devices to associate with the instance. 

This parameter is set at creation only; it is not affected by updates. 

Accepts an array of hashes with the device name and either the volume size or snapshot id specified:

```puppet
block_devices => [
  {
    device_name  => '/dev/sda1',
    volume_size  => 8,
  }
]
```

```puppet
block_devices => [
  {
    device_name  => '/dev/sda1',
    volume_type => 'gp2',
  }
]
```

##### `vpc`

Optional.

A hint to specify the VPC. This is useful when detecting ambiguously named security groups that might exist in different VPCs, such as 'default'.

This parameter is set at creation only; it is not affected by updates.

#### Type: ec2_scalingpolicy

##### `name`

Required.

The name of the scaling policy. This is the value of the AWS Name tag.

##### `scaling_adjustment`

Required.

The amount to adjust the size of the group by.

Valid values are: 

Dependent on `adjustment_type` chosen.

See [AWS Dynamic Scaling](http://docs.aws.amazon.com/AutoScaling/latest/DeveloperGuide/as-scale-based-on-demand.html) documentation.

##### `region`

Required.

The region in which to launch the policy. 

Valid values are:

See [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

##### `adjustment_type`

Required.

The type of policy. 

Accepts a string specifying the policy adjustment type. 

Valid values are:

See [Adjustment Type](http://docs.aws.amazon.com/AutoScaling/latest/APIReference/API_AdjustmentType.html) documentation.

##### `auto_scaling_group`

Required.

The name of the auto scaling group to attach the policy to. This is the value of the AWS Name tag. 

This parameter is set at creation only; it is not affected by updates.

#### Type: ec2_vpc

##### `name`

Required.

The name of the VPC. This is the value of the AWS Name tag.

##### `region`

Optional.

The region in which to launch the VPC. 

Valid values are:

See [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

##### `cidr_block`

Optional.

The IP range for the VPC. 

This parameter is set at creation only; it is not affected by updates.

##### `dhcp_options`

Optional.

The name of DHCP option set to use for this VPC. 

This parameter is set at creation only; it is not affected by updates.

##### `instance_tenancy`

Optional.

The supported tenancy options for instances in this VPC. 

This parameter is set at creation only; it is not affected by updates. 

Valid values are: 'default', 'dedicated'. 

Default value: 'default'.

##### `enable_dns_support`

Optional.

Whether or not DNS resolution is supported for the VPC. 

Valid values are: `true`, `false`. 

Default value: `true`.

##### `enable_dns_hostnames`

Optional.

Whether or not instances launched in the VPC get public DNS hostnames. 

Valid values are: `true`, `false`. 

Default value: `true`.

##### `tags`

Optional.

The tags to assign to the VPC. 

Accepts a key => value hash of tags.

#### Type: ec2_vpc_customer_gateway

##### `name`

Required.

The name of the customer gateway. This is the value of the AWS Name tag.

##### `ip_address`

Required.

The IPv4 address for the customer gateway. 

This parameter is set at creation only; it is not affected by updates. 

Valid values are:

A valid IPv4 address.

##### `bgp_asn`

Required.

The Autonomous System Numbers for the customer gateway. 

This parameter is set at creation only; it is not affected by updates.

##### `tags`

Optional.

The tags for the customer gateway. 

Accepts a key => value hash of tags.

##### `region`

Optional.

The region in which to launch the customer gateway. 

Valid values are:

See [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

##### `type`

The type of customer gateway. 'ipsec.1' is currently the only supported value.

Valid values are: 'ipsec.1'

Default value: 'ipsec.1'

#### Type: ec2_vpc_dhcp_options

##### `name`

Required.

The name of the DHCP options set. This is the value of the AWS Name tag.

##### `tags`

Optional.

Tags for the DHCP option set. 

Accepts a key => value hash of tags.

##### `region`

Optional.

The region in which to assign the DHCP option set. 

Valid values are:

See [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

##### `domain_name`

Optional.

The domain name for the DHCP options. 

This parameter is set at creation only; it is not affected by updates. 

Valid values are:

An array or a single valid domain. An array is converted to a space separated list, as Linux supports. Other OSes may not support more than one according to Amazon.

##### `domain_name_servers`

Optional.

A list of domain name servers to use for the DHCP options set. 

This parameter is set at creation only; it is not affected by updates. 

Accepts an array of domain server names.

##### `ntp_servers`

Optional.

A list of NTP servers to use for the DHCP options set. 

This parameter is set at creation only; it is not affected by updates. 

Accepts an array of NTP server names.

##### `netbios_name_servers`

Optional.

A list of netbios name servers to use for the DHCP options set. 

This parameter is set at creation only; it is not affected by updates. 

Accepts an array.

##### `netbios_node_type`

Optional.

The netbios node type. 

This parameter is set at creation only; it is not affected by updates. 

Valid values are: 1, 2, 4, 8.

#### Type: ec2_vpc_internet_gateway

##### `name`

Required.

The name of the internet gateway. This is the value of the AWS Name tag.

##### `tags`

Optional.

Tags to assign to the internet gateway. 

Accepts a key => value hash of tags.

##### `region`

Optional.

The region in which to launch the internet gateway. 

Valid values are:

See [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

##### `vpc`

Optional.

The vpc to assign this internet gateway to. 

This parameter is set at creation only; it is not affected by updates.

#### Type: ec2_vpc_routetable

##### `name`

Required.

The name of the route table. This is the value of the AWS Name tag.

##### `vpc`

Optional.

VPC to assign the route table to. 

This parameter is set at creation only; it is not affected by updates.

##### `region`

Optional.

The region in which to launch the route table. 

Valid values are:

See [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

##### `routes`

Optional.

Individual routes for the routing table. 

This parameter is set at creation only; it is not affected by updates. 

Accepts an array of 'destination_cidr_block' and 'gateway' values:

```puppet
routes => [
    {
      destination_cidr_block => '10.0.0.0/16',
      gateway                => 'local'
    },{
      destination_cidr_block => '0.0.0.0/0',
      gateway                => 'sample-igw'
    },
  ],
```

##### `tags`

Optional.

Tags to assign to the route table. 

Accepts a key => value hash of tags.

#### Type: ec2_vpc_subnet

##### `name`

Required.

The name of the subnet. This is the value of the AWS Name tag.

##### `vpc`

Optional.

VPC to assign the subnet to. 

This parameter is set at creation only; it is not affected by updates.

##### `region`

Required.

The region in which to launch the subnet. 

Valid values are:

See [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

##### `cidr_block`

Optional.

The IP address range for the subnet. 

This parameter is set at creation only; it is not affected by updates.

##### `availability_zone`

Optional.

The availability zone in which to launch the subnet. 

This parameter is set at creation only; it is not affected by updates.

##### `tags`

Optional.

Tags to assign to the subnet. 

Accepts a key => value hash of tags.

##### `route_table`

The route table to attach to the subnet. 

This parameter is set at creation only; it is not affected by updates.

##### `routes`

Optional.

Individual routes for the routing table. 

Accepts an array of 'destination_cidr_block' and 'gateway' values:

##### `id`

Read-only.

Unique string enumerated from existing resources uniquely identifying the subnet.

``` puppet
routes => [
    {
      destination_cidr_block => '10.0.0.0/16',
      gateway                => 'local'
    },{
      destination_cidr_block => '0.0.0.0/0',
      gateway                => 'sample-igw'
    },
  ],
```

##### `tags`

Optional.

Tags to assign to the route table. 

Accepts a key => value hash of tags.

#### Type: ec2_vpc_vpn

##### `name`

Required.

The name of the VPN. This is the value of the AWS Name tag.

##### `vpn_gateway`

Required.

The VPN gateway to attach to the VPN. 

This parameter is set at creation only; it is not affected by updates.

##### `customer_gateway`

Required.

The customer gateway to attach to the VPN.

This parameter is set at creation only; it is not affected by updates.

##### `type`

Optional.

The type of VPN gateway. 'ipsec.1' is currently the only supported value.

This parameter is set at creation only; it is not affected by updates. 

Valid values are: 'ipsec.1'

Default value: 'ipsec.1'

##### `routes`

Optional.

The list of routes for the VPN. 

This parameter is set at creation only; it is not affected by updates. 

Valid values are: 

IP ranges like: 'routes           => ['0.0.0.0/0']'

##### `static_routes`

Optional.
 
Whether or not to use static routes. 

This parameter is set at creation only; it is not affected by updates. 

Valid values are: `true`, `false`. 

Default value: `true`.

##### `region`

Optional.

The region in which to launch the VPN. 

Valid values are:

See [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

##### `tags`

Optional.

The tags for the VPN. 

Accepts a key => value hash of tags.

#### Type: ec2_vpc_vpn_gateway

##### `name`

Required.

The name of the VPN gateway. 

Accepts the value of the VPN gateway's Name tag.

##### `tags`

Optional.

The tags to assign to the VPN gateway. 

Accepts a key => value hash of tags.

##### `vpc`

Required.

The VPN to attach the VPN gateway to. 

This parameter is set at creation only; it is not affected by updates.

##### `region`

Required.

The region in which to launch the VPN gateway. 

Valid values are:

See [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

##### `availability_zone`

Optional.

The availability zone in which to launch the VPN gateway. 

This parameter is set at creation only; it is not affected by updates.

##### `type`

Optional.
 
The type of VPN gateway. 'ipsec.1' is currently the only supported value.

This parameter is set at creation only; it is not affected by updates. 

Valid values are: 'ipsec.1'

Default value: 'ipsec.1'

#### Type: ecs_cluster

Type representing ECS clusters.

``` puppet
ecs_cluster { 'medium':
  ensure => present,
}
```

##### `name`

Required.

The name of the cluster to manage.

#### Type: ecs_service

``` puppet
ecs_service { 'dockerdockerdockerdocker':
  ensure                   => present,
  desired_count            => 1,
  task_definition          => 'dockerdocker',
  cluster                  => 'medium',
  deployment_configuration => {
    'maximum_percent'         => 200,
    'minimum_healthy_percent' => 50
  },
  load_balancers           => [
    {
      'container_name'     => 'mycontainername',
      'container_port'     => '8080',
      'load_balancer_name' => 'name-of-loadbalancer-elb'
    }
}
```

##### `cluster`

Required.

The name of the cluster to assign the service to.

##### `deployment_configuration`

The deployment configuration of the service.

A hash with the keys of "maximum_percent" and "minimum_healthy_percent" with integer values representing percent.

##### `desired_count`

A count of this service that should be running.

##### `load_balancers`

An array of hashes representing the load balancers to assign to a service.

##### `name`

Required.

The name of the cluster to manage.

##### `role`

The short name of the role to assign to the cluster upon creation.

##### `task_definition`

Required.

The name of the task definition to run.

#### Type: ecs_task_definition

Type representing ECS clusters.

ECS task definitions can be a bit fussy.  To discover the existing containers we use the 'name' option within a container definition to calculate the differences between what is, and what should be.  Omitting the 'name' option may be done, but it would result in a new container being generated each Puppet run, and thus a new task definition.  For this reason it is recommended that  the 'name' option be defined in each container definition and that the name chosen be unique within an 'ecs_task_definition' resource.

``` puppet
ecs_task_definition { 'dockerdocker':
  container_definitions => [
    {
      'name'          => 'zleslietesting',
      'cpu'           => '1024',
      'environment'   => {
        'one' => '1',
        'two' => '2',
      },
      'essential'     => 'true',
      'image'         => 'debian:jessie',
      'memory'        => '512',
      'port_mappings' => [
        {
          'container_port' => '8081',
          'host_port'      => '8082',
          'protocol'       => 'tcp',
        },
      ],
    }
  ],
}
```

It's important to consider the behavior of the provider in the case of missing container options.

If the task for an 'ecs_task_definition' has been discovered to exist, then the discovered container options are merged with the requested options.  This results in the following behavior: *Container options not defined in the puppet resource, but are found to exist in the discovered running container are copied from the running container.*

In the case where a user wishes to remove an option from the container, one of the following can be applied.

* Name the container something else.  This results in a failure to match the existing container against the desired container, and replaces the container entirely.

* Set an empty value for the option.  This results in the option specified by the user replacing the value defined in the existing container.  For string options, simply setting the value to `''`, or as an array value `[]`, etc.

##### `container_definitions`

An array of hashes representing the container definition.  See the example above.

##### `name`

Required.

The name of the task to manage.

##### `volumes`

An array of hashes to handle for the task.  The hashes representing a volume should be in the following form:

``` puppet
{
  name => "StringNameForReference",
  host => {
    source_path => "/some/path",
  },
}
```

##### `replace_image`

A boolean to turn off the replacement of container images.  This enables Puppet to create, but not modify the image of a container once created. This is useful in environments where external CI tooling is responsible for modifying the image of a container, allowing a dualistic approach for managing ECS.

##### `role`

A string of the short name or full ARN of the IAM role that containers in this task should assume.

#### Type: iam_group

``` puppet
iam_group { 'root':
  ensure  => present,
  members => [ 'alice', 'bob' ]
}
```

##### `members`

Required.

An array of user names to include in the group.  Users not specified in this array will be removed.

#### Type: iam_instance_profile

``` puppet
iam_instance_profile { 'my_iam_role':
  ensure  => present,
  roles => [ 'my_iam_role' ],
}
```

##### `ensure`

Specifies the basic state of the resource. 

Valid values are: 'present', 'absent'.

##### `name`

Required.

The name of the IAM instance profile.

##### `roles`

Optional. 

The IAM role(s) to associate this instance profile with. 

Accepts an array for multiple roles.

#### Type: iam_policy

[IAMPolicies](http://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html) manage access to AWS resources.  The 'iam_policy' type only manages the document content of the policy, and not which entities have the policy attached.  See the 'iam_policy_attachment' type for managing the application of the policy created with the 'iam_policy' type.

``` puppet
iam_policy { 'root':
  ensure      => present,
  document    => '{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": "*",
          "Resource": "*"
        }
      ]
    }',
}
```

It is worth noting here that the 'iam_policy' type will allow the creation of an IAM policy who's name is identical to the built-in policies.  In such a case when two policies exist with the same name, one built-in and one user-defined, the user-defined is selected for management.

##### `document`

Required.

A string containing the IAM policy in JSON format.

#### Type: iam_policy_attachment

The 'iam_policy_attachment' resource manages which entities are attached to the named policy.  See the note in the 'iam_policy' above about duplicate policy name selection.

You only need to set the 'users', 'groups' or 'roles' parameters to manage the policy attachments for those resources.  Leaving one of those parameters undefined ignores the attachment for those entities.  Defining attachment for an entity as an empty array will detach all entities of that flavor from the named policy.

``` puppet
iam_policy_attachment { 'root':
  groups => ['root'],
  users  => [],
}
```

##### `groups`

Optional.

An array of group names to attach to the policy.  

**If not mentioned in this array it will be detached from the policy.**

##### `users`

Optional.

An array of user names to attach to the policy.  

**If not mentioned in this array it will be detached from the policy.**

##### `roles`

Optional.

An array of role names to attach to the policy.  

**If not mentioned in this array it will be detached from the policy.**

#### Type: iam_role

The 'iam_role' type manages IAM roles.  

``` puppet
iam_role { 'devtesting':
  ensure => present,
  policy_document => '[
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]',
}
```

All parameters are read-only once created.

##### `ensure`

Specifies the basic state of the resource. 

Valid values are: 'present', 'absent'.

##### `name`

The name of the IAM role

##### `path`

Optional.

Role path

##### `policy_document`

A string containing the IAM policy in JSON format which controls which entities may assume this role.

Default:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

##### `arn`

The Amazon Resource Name for this IAM role.

#### Type: iam_user

The 'iam_user' type manages user accounts in IAM.  Only the user's name is required as the title of the resource.

``` puppet
iam_user { 'alice':
  ensure => present,
}

iam_user { 'bob':
  ensure => present,
}
```

#### Type: kms

The 'kms' type manages KMS key lifecycle and their policies.  The name of the resource is prefixed with 'alias/' to set the alias of the KMS key, since keys themselves don't have any notion of name, outside of an attached alias.

``` puppet
kms { 'somekey':
  ensure => present,
  policy => template('my/policy.json'),
}
```

The above resource may be viewable elsewhere as 'alias/somekey'.

##### `policy`

The JSON policy document to manage on the given KMS key.

#### Type: rds_db_parameter_group

Note that currently, this type can only be listed via `puppet resource`, but cannot be created by Puppet.

##### `name`

The name of the parameter group.

##### `region`

The region in the parameter group is present. 

Valid values are: 

See [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

##### `description`

The description of the parameter group. 

Valid values are: A string.

##### `family`

The name of the database family with which the parameter group is compatible; for instance, 'mysql5.1'.

#### Type: rds_db_securitygroup

##### `name`

Required.

The name of the RDS DB security group.

##### `description`

A description of the RDS DB security group.

Valid values are: A string.

This parameter is set at creation only; it is not affected by updates.

##### `region`

Required.

The region in which to launch the parameter group. 

Valid values are:

See [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

##### `owner_id`

Read-only.

The internal AWS id of the owner of the security group.

##### `security_groups`

Read-only.

Details of any EC2 security groups attached to the RDS security group.

##### `ip_ranges`

Read-only.

Details of any ip_ranges attached to the RDS security group and their current state.

#### Type: rds_db_subnet_group

##### `name`
*Required* The name of the RDS DB subnet group.

##### `description`
*Required* A description for the RDS DB subnet group.

##### `region`
*Required* The region in which to create the subnet group. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

##### `vpc`
*Required* The name of the VPC to create the subnet group in. This parameter is set at group creation only. It is not affected by updates.

##### `subnets`
*Required* A list of subnet names to include in the subnet group. AWS requires at least two subnets.

#### Type: rds_instance

##### `name`

Required.

The name of the RDS Instance.

##### `db_name`

Generally the name of database to be created. For Oracle this is the SID. Should not be set for MSSQL.

##### `region`

Required.

The region in which to launch the parameter group.

Valid values are:

See [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

##### `db_instance_class`

Required.

The size of the database instance. 

Valid values are:

See [the AWS documentation](http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.DBInstanceClass.html) for the list of sizes.

##### `availability_zone`

Optional.

The availability zone in which to place the instance.

Valid values are:

See [AWS Regions and Availability Zones](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html).

##### `engine`

Required.

The type of database to use. Current options can be found using the 'rds-describe-db-engine-versions' command from the AWS CLI. 

This parameter is set at creation only; it is not affected by updates.

##### `engine_version`

The version of the database to use. Current options can be found using the 'rds-describe-db-engine-versions' command from the AWS CLI. 

This parameter is set at creation only; it is not affected by updates.

##### `allocated_storage`

Required.

The size of the database in gigabytes. Note that minimum size constraints exist, which vary depending on the database engine selected. 

This parameter is set at creation only; it is not affected by updates.

##### `license_model`

The nature of the license for commercial database products. Currently supported values are license-included, bring-your-own-license or general-public-license.

This parameter is set at creation only; it is not affected by updates.

##### `storage_type`

The type of storage to back the database with. Currently supported values are standard, gp2 or io1. 

This parameter is set at creation only; it is not affected by updates.

##### `iops`

The number of provisioned IOPS (input/output operations per second) to be initially allocated for the instance.  

This parameter is set at creation only; it is not affected by updates.

##### `master_username`

The name of the master user for the database instance.

This parameter is set at creation only; it is not affected by updates.

##### `master_user_password`

The password for the master user.

This parameter is set at creation only; it is not affected by updates.

##### `multi_az`

Boolean. Required if you intend to run the instance across multiple availability zones.

This parameter is set at creation only; it is not affected by updates.

##### `db_subnet`

The name of an existing DB Subnet, for launching RDS instances in VPC.

This parameter is set at creation only; it is not affected by updates.

##### `db_security_groups`

Names of the database security groups to associate with the instance.

This parameter is set at creation only; it is not affected by updates.

##### `vpc_security_groups`

Names of the VPC security groups to associate with the RDS instance. Also
accepts security group IDs for backwards-compatibility.

##### `endpoint`

Read-only.

The DNS address of the database.

##### `port`

Read-only.

The port that the database is listening on.

##### `skip_final_snapshot`

Determines whether a final DB snapshot is created before the DB instance is deleted. 

Default value: `false`.

##### `db_parameter_group`

The name of an associated DB parameter group. 

Valid values are: A string.

This parameter is set at creation only; it is not affected by updates.

##### `restore_snapshot`

Specify the snapshot name to optionally trigger creating the RDS DB from a snapshot.

##### `final_db_snapshot_identifier`

The name of the snapshot created when the instance is terminated. Note that `skip_final_snapshot` must be set to `false`.

##### `backup_retention_period`

The number of days to retain backups. 

Default value: '30 days'.

##### `rds_tags`

Optional.

The tags for the instance. 

Accepts a `key => value` hash of tags.

#### Type: route53

The route53 types set up various types of Route53 records:

* `route53_a_record`: Sets up a Route53 DNS record.

* `route53_aaaa_record`: Sets up a Route53 DNS AAAA record.

* `route53_cname_record`: Sets up a Route53 CNAME record.

* `route53_mx_record`: Sets up a Route53 MX record.

* `route53_ns_record`: Sets up a Route53 DNS record.

* `route53_ptr_record`: Sets up a Route53 PTR record.

* `route53_spf_record`: Sets up a Route53 SPF record.

* `route53_srv_record`: Sets up a Route53 SRV record.

* `route53_txt_record`: Sets up a Route53 TXT record.

* `route53_zone`: Sets up a Route53 DNS zone.

All Route53 record types use the same parameters:

##### `zone`

Required.

The zone associated with this record.

##### `name`

Required.

The name of DNS record.

##### `ttl`

Optional.

The time to live for the record. 

Accepts an integer.

##### `values`

Required.

When not using `alias_target`. The values of the record. 

Accepts an array. 

*Conflicts with alias_target*.

##### `name`

Required.

The name of DNS zone group. This is the value of the AWS Name tag.

##### `alias_target`

Required.

When not using values the name of the alias resource to target. 

*Conflicts with values*.

##### `alias_target_zone`

Required.

When using `alias_target` the ID of the zone in which the alias_target resides.

#### Type: route53_zone

##### `name`

Required.

The name of DNS zone. This is the value of the AWS Name tag. Trailing dot is optional.

##### `id`

Read-only.

The AWS-generated alphanumeric ID of the zone, excluding the leading "/hostedzone/".

##### `is_private`

Optional.

True if the zone is private. Private zones require at least one associated VPC. `False` if the zone is public (default). Set at creation and cannot be changed.

##### `record_count`

Read-only.

The AWS-reported number of records in the zone. Includes NS and SOA records, so new zones start with two records.

##### `comment`

Optional.

The comment on the zone.

##### `tags`

Optional.

The tags for the zone. 

Accepts a key => value hash of tags. Excludes 'Name' tag.

##### `vpcs`

Conditional.

For private zones, an array of at least one VPC. Each VPC is a hash with the following keys:

* `region` — *Required* Region the VPC is in.
* `vpc` — *Required* Name of the VPC. Puppet will display the VPC ID if it has no name, but cannot manage VPC associations by ID; they must be named.

For public zones, validated but not used.

#### Type: s3_bucket

##### `name`

Required.

The name of the bucket to managed.

##### `policy`

A JSON parsable string of the policy to apply to the bucket.

#### Type: sqs_queue

##### `name`

Required.

The name of the SQS queue.

##### `region`

Required.

The region in which to create the SQS Queue. 

Valid values are:

See [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

##### `delay_seconds`

Optional.

The time in seconds that the delivery of all messages in the queue will be delayed. 

Default value: 0.

##### `message_retention_period`

Optional.

The number of seconds Amazon SQS retains a message. 

Default value: 345600.

##### `maximum_message_size`

Optional.

The limit of how many bytes a message can contain before Amazon SQS rejects it.

##### `visibility_timeout`

Optional.

The number of seconds during which Amazon SQS prevents other consuming components from receiving and processing a message. 

Default value: 30.

## Limitations

This module requires Ruby 1.9 or later and is only tested on Puppet versions 3.4 and later.

At the moment this module only supports a few of the resources in the AWS API. These resources also exist a bit outside the normal host level resources like 'package', 'file', 'user', etc. 

We're really interested to see how people use these new resources, and what else you would like to be able to do with the module.

Note that this module also requires at least Ruby 1.9 and is only tested on Puppet versions from 3.4.
