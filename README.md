[![Puppet
Forge](http://img.shields.io/puppetforge/v/puppetlabs/aws.svg)](https://forge.puppetlabs.com/puppetlabs/aws)
[![Build
Status](https://travis-ci.org/puppetlabs/puppetlabs-aws.svg?branch=master)](https://travis-ci.org/puppetlabs/puppetlabs-aws)

####Table of Contents

1. [Overview](#overview)
2. [Description - What the module does and why it is useful](#description)
3. [Setup](#setup)
  * [Requirements](#requirements)
  * [Installing the aws module](#installing-the-aws-module)
4. [Getting Started with aws](#getting-started-with-aws)
5. [Usage - Configuration options and additional functionality](#usage)
  * [Creating resources](#creating-resources)
  * [Creating a stack](#creating-a-stack)
  * [Managing resources from the command line](#managing-resources-from-the-command-line)
  * [Managing AWS infrastructure](#managing-aws-infrastructure)
6. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
  * [Types](#types)
  * [Parameters](#parameters)
7. [Limitations - OS compatibility, etc.](#limitations)

##Overview

The aws module manages Amazon Web Services (AWS) resources to build out cloud infrastructure.

##Description

Amazon Web Services exposes a powerful API for creating and managing
its Infrastructure as a Service platform. The aws module
allows you to drive that API using Puppet code. In the simplest case,
this allows you to create new EC2 instances from Puppet code. More
importantly, it allows you to describe your entire AWS infrastructure and
to model the relationships between different components.

##Setup

###Requirements

* Puppet 3.4 or greater
* Ruby 1.9 or greater
* Amazon AWS Ruby SDK (available as a gem)
* Retries gem

###Installing the aws module

1. Install the retries gem and the Amazon AWS Ruby SDK gem.

    * If you're using open source Puppet, the SDK gem should be installed into the same Ruby used by Puppet. Install the gems with these commands:

      `gem install aws-sdk-core`

      `gem install retries`

  * If you're running Puppet Enterprise, install both the gems with this command:

      `/opt/puppet/bin/gem install aws-sdk-core retries`

  * If you're running Puppet Enterprise 2015.2.0 or newer, install both the gems with this command:

      `/opt/puppetlabs/puppet/bin/gem install aws-sdk-core retries`

  This allows the gems to be used by the Puppet Enterprise Ruby.

  * If you're running [Puppet Server](https://github.com/puppetlabs/puppet-server), you need to make both gems available to JRuby with:

      `/opt/puppet/bin/puppetserver gem install aws-sdk-core retries`

  Once the gems are installed, restart Puppet Server.

2. Set these environment variables for your AWS access credentials:

  ~~~
  export AWS_ACCESS_KEY_ID=your_access_key_id
  export AWS_SECRET_ACCESS_KEY=your_secret_access_key
  ~~~

  Alternatively, you can place the credentials in a file at
`~/.aws/credentials` based on the following template:

  ~~~
 [default]
  aws_access_key_id = your_access_key_id
  aws_secret_access_key = your_secret_access_key
  ~~~

  If you have Puppet running on AWS, and you're running the module examples, you can instead use [IAM](http://aws.amazon.com/iam/). To do this, assign the correct role to the instance from which you're running the examples. For a sample profile with all the required permissions, see the [IAM profile example](https://github.com/puppetlabs/puppetlabs-aws/tree/master/examples/iam-profile/).

3. Finally, install the module with:

~~~
puppet module install puppetlabs-aws
~~~

#### A note on regions

By default the module looks through all regions in AWS when
determining if something is available. This can be a little slow. If you
know what you're doing you can speed things up by targeting a single
region using an environment variable.

~~~
export AWS_REGION=eu-west-1
~~~

#### A note on proxies

By default the module accesses the AWS API directly, but if you're in an
environment which doesn't have direct access you can provide a proxy
setting for all traffic like so:

~~~
export PUPPET_AWS_PROXY=http://localhost:8888
~~~

#### Configuring the aws module using an ini file

The AWS region and HTTP proxy can be provided in a file called
`puppetlabs_aws_configuration.ini` in the Puppet confdir
(`$settings::confdir`) using this format:

    [default]
      region = us-east-1
      http_proxy = http://proxy.example.com:80

##Getting Started with aws

The aws module allows you to manage AWS using the Puppet DSL. To stand up an instance with AWS, use the `ec2_instance` type. The following code sets up a very basic instance:

~~~
ec2_instance { 'instance-name':
  ensure        => present,
  region        => 'us-west-1',
  image_id      => 'ami-123456', # you need to select your own AMI
  instance_type => 't1.micro',
}
~~~

##Usage

###Creating resources

You can also set up more complex EC2 instances with a variety of AWS features, as well as
load balancers and security groups.

**Set up an instance:**

~~~
ec2_instance { 'name-of-instance':
  ensure            => present,
  region            => 'us-east-1',
  availability_zone => 'us-east-1a',
  image_id          => 'ami-123456',
  instance_type     => 't1.micro',
  monitoring        => true,
  key_name          => 'name-of-existing-key',
  security_groups   => ['name-of-security-group'],
  user_data         => template('module/file-path.sh.erb'),
  tags              => {
    tag_name => 'value',
  },
}
~~~

**Set up a security group:**

~~~
ec2_securitygroup { 'name-of-group':
  ensure      => present,
  region      => 'us-east-1',
  description => 'a description of the group',
  ingress     => [{
    protocol  => 'tcp',
    port      => 80,
    cidr      => '0.0.0.0/0',
  },{
    security_group => 'other-security-group',
  }],
  tags        => {
    tag_name  => 'value',
  },
}
~~~

**Set up a load balancer:**

~~~
elb_loadbalancer { 'name-of-load-balancer':
  ensure                  => present,
  region                  => 'us-east-1',
  availability_zones      => ['us-east-1a', 'us-east-1b'],
  instances               => ['name-of-instance', 'another-instance'],
  security_groups         => ['name-of-security-group'],
  listeners               => [{
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
  }],
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
~~~

To destroy any of these resources, set `ensure => absent`.

### Creating a stack

Let's create a simple stack, with a load balancer, instances, and security groups.

~~~
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
~~~

We've supplied code for the creation of this stack in this module's tests directory. To run this code with Puppet apply, run:

~~~
puppet apply tests/create.pp --test
~~~

If you want to try this out from this directory without installing the
module, run the following:

~~~
puppet apply tests/create.pp --modulepath ../ --test
~~~

To destroy the resources created by the above, run the following:

~~~
puppet apply tests/destroy.pp --test
~~~

### Managing resources from the command line

The module has basic `puppet resource` support, so you can manage AWS resources from the command line.

For example, the following command lists all the security groups:

~~~
puppet resource ec2_securitygroup
~~~

You can also create new resources:

~~~
puppet resource ec2_securitygroup test-group ensure=present description="test description" region=us-east-1
~~~

and then destroy them, all from the command line:

~~~
puppet resource ec2_securitygroup test-group ensure=absent region=sa-east-1
~~~


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

##Reference

### Types

* `ec2_instance`: Sets up an EC2 instance.
* `ec2_securitygroup`: Sets up an EC2 security group.
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
* `iam_policy`: Manage an IAM 'managed' policy.
* `iam_policy_attachment`: Manage an IAM 'managed' policy attachments.
* `iam_user`: Manage IAM users.
* `rds_db_parameter_group`: Allows read access to DB Parameter Groups.
* `rds_db_securitygroup`: Sets up an RDS DB Security Group.
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

###Parameters

####Type: ec2_instance

#####`ensure`
Specifies the basic state of the resource. Valid values are 'present', 'absent', 'running', 'stopped'.

#####`name`
*Required* The name of the instance. This is the value of the AWS Name tag.

#####`security_groups`
*Optional* The security groups with which to associate the instance. Accepts an array of security group names.

#####`tags`
*Optional* The tags for the instance. Accepts a 'key => value' hash of tags.

#####`user_data`
*Optional* User data script to execute on new instance. This parameter is set at creation only; it is not affected by updates.

#####`key_name`
The name of the key pair associated with this instance. This must be an existing key pair already uploaded to the region in which you're launching the instance. This parameter is set at creation only; it is not affected by updates.

#####`monitoring`
*Optional* Whether or not monitoring is enabled for this instance. This parameter is set at creation only; it is not affected by updates. Valid values are 'true', 'false'. Defaults to 'false'.

#####`region`
*Required* The region in which to launch the instance. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

#####`image_id`
*Required* The image id to use for the instance. This parameter is set at creation only; it is not affected by updates. For more information, see AWS documentation on finding your [Amazon Machine Image (AMI)](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/finding-an-ami.html).

#####`availability_zone`
*Optional* The availability zone in which to place the instance. This parameter is set at creation only; it is not affected by updates. For valid availability zone codes, see [AWS Regions and Availability Zones](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html).

#####`instance_type`
*Required* The type to use for the instance. This parameter is set at creation only; it is not affected by updates. See [Amazon EC2 Instances](http://aws.amazon.com/ec2/instance-types/) for available types.

#####`tenancy`
*Optional* Dedicated instances are Amazon EC2 instances that run in a virtual private cloud (VPC) on hardware that's dedicated to a single customer. Choices are 'dedicated' and 'default'. Defaults to shared (default) hardware.

#####`private_ip_address`
*Optional* The private IP address for the instance. This parameter is set at creation only; it is not affected by updates. Must be a valid IPv4 address.

#####`associate_public_ip_address`
*Optional* Whether to assign a public interface in a VPC. This parameter is set at creation only; it is not affected by updates. Valid values are 'true', 'false'. Defaults to 'false'.

#####`subnet`
*Optional* The VPC subnet to attach the instance to. This parameter is set at creation only; it is not affected by updates. Accepts the name of the subnet; this is the value of the Name tag for the subnet. If you're describing the subnet in Puppet, then this value is the name of the resource.

#####`ebs_optimized`
*Optional* Whether or not to use optimized storage for the instance.  This parameter is set at creation only; it is not affected by updates. Valid values are 'true', 'false'. Defaults to 'false'.

#####`instance_initiated_shutdown_behavior`
*Optional* Whether the instance stops or terminates when you initiate shutdown from the instance. This parameter is set at creation only; it is not affected by updates. Valid values are 'stop', 'terminate'. Defaults to 'stop'.

#####`block_devices`
*Optional* A list of block devices to associate with the instance. This parameter is set at creation only; it is not affected by updates. Accepts an array of hashes with the device name and either the volume size or snapshot id specified:

~~~
block_devices => [
  {
    device_name  => '/dev/sda1',
    volume_size  => 8,
  }
]
~~~

~~~
block_devices => [
  {
    device_name  => '/dev/sda1',
    snapshot_id => 'snap-29a6ca13',
  }
]
~~~

#####`instance_id`
The AWS generated id for the instance. Read-only.

#####`hypervisor`
The type of hypervisor running the instance. Read-only.

#####`virtualization_type`
The underlying virtualization of the instance. Read-only.

#####`public_ip_address`
The public IP address for the instance. Read-only.

#####`private_dns_name`
The internal DNS name for the instance. Read-only.

#####`public_dns_name`
The publicly available DNS name for the instance. Read-only.

#####`kernel_id`
The ID of the kernel in use by the instance. Read-only.

#####`iam_instance_profile_name`
The user provided name for the IAM profile to associate with the
instance.

#####`iam_instance_profile_arn`
The Amazon Resource Name for the associated IAM profile.

#### Type: ec2_securitygroup

##### `name`
*Required* The name of the security group. This is the value of the AWS Name tag.

##### `region`
*Required* The region in which to launch the security group. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

##### `ingress`
*Optional* Rules for ingress traffic. Accepts an array.

##### `id`
*Read-only* Unique string enumerated from existing resources uniquely identifying the security group.

##### `tags`
*Optional* The tags for the security group. Accepts a 'key => value' hash of tags.

##### `description`
*Required* A short description of the group. This parameter is set at creation only; it is not affected by updates.

##### `vpc`
*Optional* The VPC to which the group should be associated. This parameter is set at creation only; it is not affected by updates. Accepts the value of the Name tag for the VPC.


#### Type: elb_loadbalancer

#####`name`
*Required* The name of the load balancer. This is the value of the AWS Name tag.

#####`region`
*Required* The region in which to launch the load balancer. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

#####`listeners`
*Required* The ports and protocols the load balancer listens to. This parameter is set at creation only; it is not affected by updates. Accepts an array of the following values:
  * protocol
  * load_balancer_port
  * instance_protocol
  * instance_port
  * ssl_certificate_id (optional if protocol is HTTPS )

#####`health_check`
The configuration for an ELB health check used to determine the health of the
back- end instances.  Accepts a hash with the following keys:
  * healthy_threshold
  * interval
  * target
  * timeout
  * unhealthy_threshold

#####`tags`
*Optional* The tags for the load balancer. This parameter is set at creation only; it is not affected by updates. Accepts a 'key => value' hash of tags.

#####`subnets`
*Optional* The subnet in which the load balancer should be launched. Accepts an array of subnet names, i.e., the Name tags on the subnets. You can only set one of `availability_zones` or `subnets`.

#####`security_groups`
*Optional* The security groups to associate with the load balancer (VPC only). Accepts an array of security group names, i.e., the Name tag on the security groups.

#####`availability_zones`
*Optional* The availability zones in which to launch the load balancer. This parameter is set at creation only; it is not affected by updates. Accepts an array on availability zone codes. For valid availability zone codes, see [AWS Regions and Availability Zones](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html). You can only set one of `availability_zones` or `subnets`.

#####`instances`
*Optional* The instances to associate with the load balancer. Accepts an array of names, i.e., the Name tag on the instances.

#####`scheme`
*Optional* Whether the load balancer is internal or public facing. This parameter is set at creation only; it is not affected by updates. Valid values are 'internal', 'internet-facing'. Default value is 'internet-facing' and makes the load balancer publicly available.

#### Type: cloudwatch_alarm

##### `name`
*Required* The name of the alarm. This is the value of the AWS Name tag.

##### `metric`
*Required* The name of the metric to track.

##### `namespace`
*Required* The namespace of the metric to track.

##### `statistic`
*Required* The statistic to track for the metric.

##### `period`
*Required* The periodicity of the alarm check, i.e., how often the alarm check should run.

##### `evaluation_periods`
*Required* The number of checks to use to confirm the alarm.

##### `threshold`
*Required* The threshold used to trigger the alarm.

##### `comparison_operator`
*Required* The operator to use to test the metric.

##### `region`
*Required* The region in which to launch the instances. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

##### `dimensions`
*Optional* The dimensions by which to filter the alarm by. For more information about EC2 dimensions, see AWS [Dimensions and Metrics](http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/ec2-metricscollected.html) documentation.

##### `alarm_actions`
*Optional* The actions to trigger when the alarm triggers. This parameter is set at creation only; it is not affected by updates. This parameter currently supports only named scaling policies.

#### Type: ec2_autoscalinggroup

##### `name`
*Required* The name of the auto scaling group. This is the value of the AWS Name tag.

##### `min_size`
*Required* The minimum number of instances in the group.

##### `max_size`
*Required* The maximum number of instances in the group.

##### `desired_capacity`
*Optional* The number of EC2 instances that should be running in the group. This number must be greater than or equal to the minimum size of the group and less than or equal to the maximum size of the group. Defaults to `min_size`.

##### `default_cooldown`
*Optional* The amount of time, in seconds, after a scaling activity completes before another scaling activity can start.

##### `health_check_type`
*Optional* The service to use for the health checks. The valid values are `'EC2'` and `'ELB'`.

##### `health_check_grace_period`
*Optional* The amount of time, in seconds, that Auto Scaling waits before checking the health status of an EC2 instance that has come into service. During this time, any health check failures for the instance are ignored. The default is 300. This parameter is required if you are adding an ELB health check.

##### `new_instances_protected_from_scale_in`
*Optional* Indicates whether newly launched instances are protected from termination by Auto Scaling when scaling in. Defaults to true.

##### `region`
*Required* The region in which to launch the instances. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

#####`launch_configuration`
*Required* The name of the launch configuration to use for the group. This is the value of the AWS Name tag.

##### `availability_zones`
*Required* The availability zones in which to launch the instances. Accepts an array of availability zone codes. For valid availability zone codes, see [AWS Regions and Availability Zones](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html).

##### `load_balancers`
*Optional* A list of load balancer names that should be attached to this autoscaling group.

##### `subnets`
*Optional* The subnets to associate with the autoscaling group.

#####`tags`
*Optional* The tags to assign to the autoscaling group. Accepts a 'key => value' hash of tags. The tags are not propagated to launched instances.

#### Type: ec2_elastic_ip

#####`ensure`
Specifies that basic state of the resource. Valid values are 'attached', 'detached'.

#####`name`
*Required* The IP address of the Elastic IP. Accepts a valid IPv4 address of an already existing elastic IP.

#####`region`
*Required* The region in which the Elastic IP is found. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

#####`instance`
*Required* The name of the instance associated with the Elastic IP. This is the value of the AWS Name tag.


#### Type: ec2_launchconfiguration

#####`name`
*Required* The name of the launch configuration. This is the value of the AWS Name tag.

#####`security_groups`
*Required* The security groups to associate with the instances. This parameter is set at creation only; it is not affected by updates. Accepts an array of security group names, i.e., the Name tags on the security groups.

#####`user_data`
*Optional* User data script to execute on new instances. This parameter is set at creation only; it is not affected by updates.

#####`key_name`
*Optional* The name of the key pair associated with this instance. This parameter is set at creation only; it is not affected by updates.

#####`region`
*Required* The region in which to launch the instances. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

#####`instance_type`
*Required* The type to use for the instances. This parameter is set at creation only; it is not affected by updates. See [Amazon EC2 Instances](http://aws.amazon.com/ec2/instance-types/) for available types.

#####`image_id`
*Required* The image id to use for the instances. This parameter is set at creation only; it is not affected by updates. For more information, see AWS documentation on finding your [Amazon Machine Image (AMI)](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/finding-an-ami.html).

#####`block_device_mappings`
*Optional* A list of block devices to associate with the instance. This parameter is set at creation only; it is not affected by updates. Accepts an array of hashes with the device name and either the volume size or snapshot id specified:

~~~
block_devices => [
  {
    device_name  => '/dev/sda1',
    volume_size  => 8,
  }
]
~~~

~~~
block_devices => [
  {
    device_name  => '/dev/sda1',
    volume_type => 'gp2',
  }
]
~~~

#####`vpc`
*Optional* A hint to specify the VPC. This is useful when detecting ambiguously named security groups that might exist in different VPCs, such as 'default'. This parameter is set at creation only; it is not affected by updates.

#### Type: ec2_scalingpolicy

#####`name`
*Required* The name of the scaling policy. This is the value of the AWS Name tag.

#####`scaling_adjustment`
*Required* The amount to adjust the size of the group by. Valid values depend on `adjustment_type` chosen. See [AWS Dynamic Scaling](http://docs.aws.amazon.com/AutoScaling/latest/DeveloperGuide/as-scale-based-on-demand.html) documentation.

#####`region`
*Required* The region in which to launch the policy. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

#####`adjustment_type`
*Required* The type of policy. Accepts a string specifying the policy adjustment type. For valid values, see AWS [Adjustment Type](http://docs.aws.amazon.com/AutoScaling/latest/APIReference/API_AdjustmentType.html) documentation.

#####`auto_scaling_group`
*Required* The name of the auto scaling group to attach the policy to. This is the value of the AWS Name tag. This parameter is set at creation only; it is not affected by updates.

#### Type: ec2_vpc

#####`name`
*Required* The name of the VPC. This is the value of the AWS Name tag.

#####`region`
*Optional* The region in which to launch the VPC. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

#####`cidr_block`
*Optional* The IP range for the VPC. This parameter is set at creation only; it is not affected by updates.

#####`dhcp_options`
*Optional* The name of DHCP option set to use for this VPC. This parameter is set at creation only; it is not affected by updates.

#####`instance_tenancy`
*Optional* The supported tenancy options for instances in this VPC. This parameter is set at creation only; it is not affected by updates. Valid values are 'default', 'dedicated'. Defaults to 'default'.

#####`tags`
*Optional* The tags to assign to the VPC. Accepts a 'key => value' hash of tags.

#### Type: ec2_vpc_customer_gateway

#####`name`
*Required* The name of the customer gateway. This is the value of the AWS Name tag.

#####`ip_address`
*Required* The IPv4 address for the customer gateway. This parameter is set at creation only; it is not affected by updates. Accepts a valid IPv4 address.

#####`bgp_asn`
*Required* The Autonomous System Numbers for the customer gateway. This parameter is set at creation only; it is not affected by updates.

#####`tags`
*Optional* The tags for the customer gateway. Accepts a 'key => value' hash of tags.

#####`region`
*Optional* The region in which to launch the customer gateway. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

#####`type`
The type of customer gateway. The only currently supported value --- and the default --- is 'ipsec.1'.

#### Type: ec2_vpc_dhcp_options

#####`name`
*Required* The name of the DHCP options set. This is the value of the AWS Name tag.

#####`tags`
*Optional* Tags for the DHCP option set. Accepts a 'key => value' hash of tags.

#####`region`
*Optional* The region in which to assign the DHCP option set. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

#####`domain_name`
*Optional* The domain name for the DHCP options. This parameter is set at creation only; it is not affected by updates. Accepts any valid domain.

#####`domain_name_servers`
*Optional* A list of domain name servers to use for the DHCP options set. This parameter is set at creation only; it is not affected by updates. Accepts an array of domain server names.

#####`ntp_servers`
*Optional* A list of NTP servers to use for the DHCP options set. This parameter is set at creation only; it is not affected by updates. Accepts an array of NTP server names.

#####`netbios_name_servers`
*Optional* A list of netbios name servers to use for the DHCP options set. This parameter is set at creation only; it is not affected by updates. Accepts an array.

#####`netbios_node_type`
*Optional* The netbios node type. This parameter is set at creation only; it is not affected by updates. Valid values are '1', '2', '4', '8'. Defaults to '2'.


#### Type: ec2_vpc_internet_gateway

#####`name`
*Required* The name of the internet gateway. This is the value of the AWS Name tag.

#####`tags`
*Optional* Tags to assign to the internet gateway. Accepts a 'key => value' hash of tags.

#####`region`
*Optional* The region in which to launch the internet gateway. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

#####`vpc`
*Optional* The vpc to assign this internet gateway to. This parameter is set at creation only; it is not affected by updates.


#### Type: ec2_vpc_routetable

#####`name`
*Required* The name of the route table. This is the value of the AWS Name tag.

#####`vpc`
*Optional* VPC to assign the route table to. This parameter is set at creation only; it is not affected by updates.

#####`region`
*Optional* The region in which to launch the route table. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

#####`routes`
*Optional* Individual routes for the routing table. This parameter is set at creation only; it is not affected by updates. Accepts an array of 'destination_cidr_block' and 'gateway' values:

~~~
routes => [
    {
      destination_cidr_block => '10.0.0.0/16',
      gateway                => 'local'
    },{
      destination_cidr_block => '0.0.0.0/0',
      gateway                => 'sample-igw'
    },
  ],
~~~

#####`tags`
*Optional* Tags to assign to the route table. Accepts a 'key => value' hash of tags.


#### Type: ec2_vpc_subnet

#####`name`
*Required* The name of the subnet. This is the value of the AWS Name tag.

#####`vpc`
*Optional* VPC to assign the subnet to. This parameter is set at creation only; it is not affected by updates.

#####`region`
*Required* The region in which to launch the subnet. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

#####`cidr_block`
*Optional* The IP address range for the subnet. This parameter is set at creation only; it is not affected by updates.

#####`availability_zone`
*Optional* The availability zone in which to launch the subnet. This parameter is set at creation only; it is not affected by updates.

#####`tags`
*Optional* Tags to assign to the subnet. Accepts a 'key => value' hash of tags.

#####`route_table`
The route table to attach to the subnet. This parameter is set at creation only; it is not affected by updates.

#####`region`
*Optional* Region in which to launch the route table. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

#####`routes`
*Optional* Individual routes for the routing table. Accepts an array of 'destination_cidr_block' and 'gateway' values:

##### `id`
*Read-only* Unique string enumerated from existing resources uniquely identifying the subnet.


~~~
routes => [
    {
      destination_cidr_block => '10.0.0.0/16',
      gateway                => 'local'
    },{
      destination_cidr_block => '0.0.0.0/0',
      gateway                => 'sample-igw'
    },
  ],
~~~

#####`tags`
*Optional* Tags to assign to the route table. Accepts a 'key => value' hash of tags.


#### Type: ec2_vpc_vpn

#####`name`
*Required* The name of the VPN. This is the value of the AWS Name tag.

#####`vpn_gateway`
*Required* The VPN gateway to attach to the VPN. This parameter is set at creation only; it is not affected by updates.

#####`customer_gateway`
*Required* The customer gateway to attach to the VPN. This parameter is set at creation only; it is not affected by updates.

#####`type`
*Optional* The type of VPN gateway. This parameter is set at creation only; it is not affected by updates. The only currently supported value --- and the default --- is 'ipsec.1'.

#####`routes`
*Optional* The list of routes for the VPN. This parameter is set at creation only; it is not affected by updates. Valid values are IP ranges like: `routes           => ['0.0.0.0/0']`

#####`static_routes`
*Optional* Whether or not to use static routes. This parameter is set at creation only; it is not affected by updates. Valid values are 'true', 'false'. Defaults to 'true'.

#####`region`
*Optional* The region in which to launch the VPN. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

#####`tags`
*Optional* The tags for the VPN. Accepts a 'key => value' hash of tags.

#### Type: ec2_vpc_vpn_gateway

#####`name`
*Required* The name of the VPN gateway. Accepts the value of the VPN gateway's Name tag.

#####`tags`
*Optional* The tags to assign to the VPN gateway. Accepts a 'key => value' hash of tags.

#####`vpc`
*Required* The VPN to attach the VPN gateway to. This parameter is set at creation only; it is not affected by updates.

#####`region`
*Required* The region in which to launch the VPN gateway. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

#####`availability_zone`
*Optional* The availability zone in which to launch the VPN gateway. This parameter is set at creation only; it is not affected by updates.

#####`type`
*Optional* The type of VPN gateway. This parameter is set at creation only; it is not affected by updates. The only currently supported value --- and the default --- is 'ipsec.1'.

#### Type: ecs_cluster

Type representing ECS clusters.

```Puppet
ecs_cluster { 'medium':
  ensure => present,
}
```

##### `name`
*Required* The name of the cluster to manage.

#### Type: ecs_service

```Puppet
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
*Required* The name of the cluster to assign the service to

##### `deployment_configuration`
The deployment configuration of the service.

A hash with the keys of "maximum_percent" and "minimum_healthy_percent"
with integer values represnting percent.'

##### `desired_count`
A count of this service that should be running.

##### `load_balancers`
An array of hashes representing the load balancers to assign to a service.

##### `name`
*Required* The name of the cluster to manage.

##### `role`
The short name of the role to assign to the cluster upon creation.

##### `task_definition`
*Required* The name of the task definition to run.

#### Type: ecs_task_definition

Type representing ECS clusters.

ECS task definitions can be a bit fussy.  To discover the existing containers
we use the 'name' option within a container definition to calculate the
differences between what is, and what should be.  Omitting the 'name' option may
be done, but it would result in a new container being generated each Puppet
run, and thus a new task definition.  For this reason it is recommended that
the 'name' option be defined in each container definition and that the name
chosen be unique within an `ecs_task_definition` resource.

```Puppet
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

Please note, it's important to take into consideration the behavior of the
provider in the case of missing container options.

If the task for an `ecs_task_definition` has been discovered to exist, then the
discovered container options are merged with the requested options.  This
results in the following behavior: *Container options not defined in the puppet
resource, but are found to exist in the discovered running container are copied
from the running container.*

In the case where a user wishes to remove an option from the container, one of the following can be applied.

* Name the container something else.  This results in a failure to match the
  existing container against the desired container, and replaces the container
  entirely.

* Set an empty value for the option.  This results in the option specified by
  the user replacing the value defined in the existing container.  For string
  options, simply setting the value to `''`, or as an array value `[]`, etc.

It's a small kludge, I know.



##### `container_definitions`
An array of hashes representing the container definition.  See the example
above.

##### `name`
*Required* The name of the task to manage.

##### `volumes`
An array of hashes to handle for the task.

##### `replace_image`
A boolean to turn off the replacement of container images.  This enables Puppet
to create, but not modify the image of a container once created.

This is useful in environments where external CI tooling is responsible for
modifying the image of a container, allowing a dualistic approach for managing
ECS.

#### Type: iam_group

```Puppet
iam_group { 'root':
  ensure  => present,
  members => [ 'alice', 'bob' ]
}
```

#####`members`
*Required* An array of user names to include in the group.  Users not specified in this array will be removed.

#### Type: iam_policy

[IAM
Policies](http://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html)
manage access to AWS resources.  The `iam_policy` type only manages the
document content of the policy, and not which entities have the policy
attached.  See the `iam_policy_attachment` type for managing the application of
the policy created with the `iam_policy` type.

```Puppet
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

It is worth noting here that the `iam_policy` type will allow the creation of
an IAM policy who's name is identical to the built-in policies.  In such a case
when two policies exist with the same name, one built-in and one user-defined,
the user-defined is selected for management.

#####`document`
*Required* A string containing the IAM policy in JSON format.

#### Type: iam_policy_attachment
The `iam_policy_attachment` resource manages which entities are attached to the
named policy.  See the note in the `iam_policy` above about duplicate policy
name selection.

You only need to set the `users`, `groups` or `roles` parameters to manage the
policy attachments for those resources.  Leaving one of those parameters
undefined ignores the attachment for those entities.  Defining attachment for
an entity as an empty array will detach all entities of that flavor from the
named policy.

```Puppet
iam_policy_attachment { 'root':
  groups => ['root'],
  users  => [],
}
```

#####`groups`
*Optional* An array of group names to attach to the policy.  **Group names not mentioned in this array will be detached from the policy.**

#####`users`
*Optional* An array of user names to attach to the policy.  **User names not mentioned in this array will be detached from the policy.**

#####`roles`
*Optional* An array of role names to attach to the policy.  **Role names not mentioned in this array will be detached from the policy.**

#### Type: iam_user
The `iam_user` type manages user accounts in IAM.  Only the user's name is
required as the title of the resource.

```
iam_user { 'alice':
  ensure => present,
}

iam_user { 'bob':
  ensure => present,
}
```

#### Type: rds_db_parameter_group

Note that currently, this type can only be listed via puppet resource,
but cannot be created by Puppet.

#####`name`
The name of the parameter group.

#####`region`
The region in the parameter group is present. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

#####`description`
The description of the parameter group. Should be a string.

#####`family`
The name of the database family with which the parameter group is
compatible; for instance, 'mysql5.1'.

#### Type: rds_db_securitygroup

#####`name`
*Required* The name of the RDS DB security group.

#####`description`
A description of the RDS DB security group. Should be a string. This
parameter is set at creation only; it is not affected by updates.

#####`region`
*Required* The region in which to launch the parameter group. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

#####`owner_id`
The internal AWS id of the owner of the security group. Read-only.

#####`security_groups`
Details of any EC2 security groups attached to the RDS security group. Read-only.

#####`ip_ranges`
Details of any ip_ranges attached to the RDS security group and their current state. Read-only.

#### Type: rds_instance

#####`name`
*Required* The name of the RDS Instance.

#####`db_name`
Generally the name of database to be created. For Oracle this is the SID.
Should not be set for MSSQL.

#####`region`
*Required* The region in which to launch the parameter group. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

#####`db_instance_class`
*Required* The size of the database instance. See [the AWS
documentation](http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.DBInstanceClass.html)
for the list of sizes.

#####`availability_zone`
*Optional* The availability zone in which to place the instance. For valid availability zone codes, see [AWS Regions and Availability Zones](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html).

#####`engine`
*Required* The type of database to use. Current options can be found
using the `rds-describe-db-engine-versions` command from the AWS CLI.
This parameter is set at creation only; it is not affected by updates.

#####`engine_version`
The version of the database to use. Current options can be found
using the `rds-describe-db-engine-versions` command from the AWS CLI.
This parameter is set at creation only; it is not affected by updates.

#####`allocated_storage`
The size of the database in gigabytes. Note that minimum size constraints
exist, which vary depending on the database engine selected.
This parameter is set at creation only; it is not affected by updates.

#####`license_model`
The nature of the license for commercial database products. Currently
supported values are license-included, bring-your-own-license or
general-public-license. This parameter is set at creation only; it is
not affected by updates.

#####`storage_type`
The type of storage to back the database with. Currently supported
values are standard, gp2 or io1. This parameter is set at creation only;
it is not affected by updates.

#####`iops`
The number of provisioned IOPS (input/output operations per second) to
be initially allocated for the instance. This parameter is set at
creation only; it is not affected by updates.

#####`master_username`
The name of the master user for the database instance. This parameter is
set at creation only; it is not affected by updates.

#####`master_user_password`
The password for the master user. This parameter is set at creation
only; it is not affected by updates.

#####`multi_az`
Boolean. Required if you intend to run the instance across multiple
availability zones. This parameter is set at creation only; it is not
affected by updates.

#####`db_subnet`
The name of an existing DB Subnet, for launching RDS instances in VPC.
This parameter is set at creation only; it is not affected by updates.

#####`db_security_groups`
Names of the database security groups to associate with the instance.
This parameter is set at creation only; it is not affected by updates.

#####`vpc_security_groups`
IDs of the database security groups within a VPC to associate the instance
with.  This parameter is set at creation only; it is not affected by updates.

#####`endpoint`
The DNS address of the database. Read-only.

#####`port`
The port that the database is listening on. Read-only.

#####`skip_final_snapshot`
Determines whether a final DB snapshot is created before the DB instance
is deleted. Defaults to false.

#####`db_parameter_group`
The name of an associated DB parameter group. Should be a string. This
parameter is set at creation only; it is not affected by updates.

#####`final_db_snapshot_identifier`
The name of the snapshot created when the instance is terminated. Note
that skip_final_snapshot must be set to false.

#####`backup_retention_period`
The number of days to retain backups. Defaults to 30 days.

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

#####`zone`
*Required* The zone associated with this record.

#####`name`
*Required* The name of DNS record.

#####`ttl`
*Optional* The time to live for the record. Accepts an integer.

#####`values`
*Required when not using alias_target* The values of the record. Accepts an array.
*Conflicts with alias_target*

#####`name`
*Required* The name of DNS zone group. This is the value of the AWS Name tag.

#####`alias_target`
*Required when not using values* The name of the alias resource to target.
*Conflicts with values*

#####`alias_target_zone`
*Required when using alias_target* The ID of the zone in which the alias_target resides.

#### Type: route53_zone

#####`name`
*Required* The name of DNS zone group. This is the value of the AWS Name tag.

#### Type: s3_bucket

#####`name`
*Required* The name of the bucket to managed.

#####`policy`
A JSON parsable string of the policy to apply to the bucket.

#### Type: sqs_queue
#####`name`
*Required* The name of the SQS queue.

#####`region`
*Required* The region in which to create the SQS Queue. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

#####`delay_seconds`
*Optional* The time in seconds that the delivery of all messages in the queue will be delayed. Default value: 0

#####`message_retention_period`
*Optional* The number of seconds Amazon SQS retains a message. Default value: 345600

#####`maximum_message_size`
*Optional* The limit of how many bytes a message can contain before Amazon SQS rejects it.

#####`visibility_timeout`
*Optional* The number of seconds during which Amazon SQS prevents other consuming components from receiving and processing a message. Default value: 30


##Limitations

This module requires Ruby 1.9 or later and is only tested on Puppet
versions 3.4 and later.

At the moment this module only supports a few of the resources
in the AWS API. These resources also exist a bit outside the
normal host level resources like `package`, `file`, `user`, etc. We're
really interested to see how people use these new resources, and what
else you would like to be able to do with the module.

Note that this module also requires at least Ruby 1.9 and is only tested on Puppet
versions from 3.4. If this is too limiting please let us know.
