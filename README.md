[![Puppet
Forge](http://img.shields.io/puppetforge/v/puppetlabs/aws.svg)](https://forge.puppetlabs.com/puppetlabs/aws) [![Build
Status](https://travis-ci.org/puppetlabs/puppetlabs-aws.svg?branch=master)](https://travis-ci.org/puppetlabs/puppetlabs-aws)

####Table of Contents

1. [Overview](#overview)
2. [Description - What the module does and why it is useful](#module-description)
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
* Ruby 1.9
* Amazon AWS Ruby SDK (available as a gem)
* Retries gem

###Installing the aws module

1. Install the retries gem and the Amazon AWS Ruby SDK gem. 

    * If you're using open source Puppet, the SDK gem should be installed into the same Ruby used by Puppet. Install the gems with these commands:

      `gem install aws-sdk-core`

      `gem install retries`

  * If you're running Puppet Enterprise, install both the gems with this command: 

      `/opt/puppet/bin/gem install aws-sdk-core retries`
    
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

  If you have Puppet running on AWS, and you're running the module examples, you can instead use [IAM](http://aws.amazon.com/iam/). To do this, assign the correct role to the instance from which you're running the examples. For a sample profile with all the required permissions, see the [IAM profile example](examples/iam-profile/).

3. Finally, install the module with:

~~~
puppet module install puppetlabs-aws
~~~

### A note on regions

By default the module will look through all regions in AWS when
determining if something is available. This can be a little slow. If you
know what you're doing you can speed things up by targeting a single
region using an environment variable.

~~~
export AWS_REGION=eu-west-1
~~~

##Getting Started with aws

The aws module allows you to manage AWS using the Puppet DSL. To stand up an instance with AWS, use the `ec2_instance` type. The following code sets up a very basic instance: 

~~~
ec2_instance { 'instance-name':
  region          => 'us-west-1',
  ensure          => present,
  image_id        => 'ami-123456', # you need to select your own AMI
  instance_type   => 't1.micro',
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
  ensure               => present,
  region               => 'us-east-1',
  availability_zones   => ['us-east-1a', 'us-east-1b'],
  instances            => ['name-of-instance', 'another-instance'],
  security_groups      => ['name-of-security-group'],
  listeners            => [{
    protocol           => 'tcp',
    load_balancer_port => 80,
    instance_protocol  => 'tcp',
    instance_port      => 80,
  }],
  tags                 => {
    tag_name => 'value',
  },
}
~~~


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

For example, the following command will list all the security groups:

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

You can use the aws module to audit AWS resources, launch autoscaling groups in VPC, perform unit testing, and more. The [examples](/examples) directory in the module contains a variety of usage examples that should give you an idea of what's possible:

* [Puppet Enterprise](/examples/puppet-enterprise/): Start up a small Puppet Enterprise cluster using the AWS module.
* [Managing DNS](/examples/manage-dns/): Manage DNS records in Amazon Route53 using Puppet.
* [Data Driven Manifests](./examples/data-driven-manifests/): Automatically generate resources based on a data structure.
* [Hiera Example](/examples/hiera-example/): Store common information like region or AMI id in Hiera.
* [Infrastructure as YAML](/examples/yaml-infrastructure-definition/): Describe an entire infrastructure stack in YAML, and use `create_resources` and Hiera to build your infrastructure.
* [Auditing Resources](/examples/audit-security-groups/): Audit AWS resource changes and work alongside other tools.
* [Unit Testing](/examples/unit-testing): Test your AWS code with Puppet testing tools like rspec-puppet.
* [Virtual Private Cloud](/examples/vpc-example): Use the Puppet DSL to manage a AWS VPC environment.
* [Using IAM permissions](/examples/iam-profile): Control the API permissions required by the module with an IAM profile.
* [Elastic IP Addresses](/examples/elastic-ip-addresses/): Attach existing elastic IP addresses to instances managed by Puppet.
  
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
* `route53_a_record`: Sets up a Route53 DNS record.
* `route53_aaaa_record`: Sets up a Route53 DNS AAAA record.
* `route53_cname_record`: Sets up a Route53 CNAME record.
* `route53_mx_record`: Sets up a Route53 MX record.
* `route53_ns_record`: Sets up a Route53 DNS record.
* `route53_spf_record`: Sets up a Route53 SPF record.
* `route53_srv_record`: Sets up a Route53 SRV record.
* `route53_txt_record`: Sets up a Route53 TXT record.
* `route53_zone`: Sets up a Route53 DNS zone.

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
*Optional* User data script to execute on new instance.

#####`key_name`
The name of the key pair associated with this instance. This must be an existing key pair already uploaded to the region in which you're launching the instance.

#####`monitoring`
*Optional* Whether or not monitoring is enabled for this instance. Valid values are 'true', 'false'. Defaults to 'false'.

#####`region`
*Required* The region in which to launch the instance. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region). 

#####`image_id`
*Required* The image id to use for the instance. For more information, see AWS documentation on finding your [Amazon Machine Image (AMI)](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/finding-an-ami.html). 

#####`availability_zone`
*Optional* The availability zone in which to place the instance. For valid availability zone codes, see [AWS Regions and Availability Zones](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html).

#####`instance_type`
*Required* The type to use for the instance. See [Amazon EC2 Instances](http://aws.amazon.com/ec2/instance-types/) for available types.

#####`private_ip_addresS`
*Optional* The private IP address for the instance. Must be a valid IPv4 address.

#####`associate_public_ip_address`
*Optional* Whether to assign a public interface in a VPC. Valid values are 'true', 'false'. Defaults to 'false'.

#####`subnet`
*Optional* The VPC subnet to attach the instance to. Accepts the name of the subnet; this is the value of the Name tag for the subnet. If you're describing the subnet in Puppet, then this value will be the name of the resource. 

#####`ebs_optimized`
*Optional* Whether or not to use optimized storage for the instance. Valid values are 'true', 'false'. Defaults to 'false'.

#####`instance_initiated_shutdown_behavior`
*Optional* Whether the instance stops or terminates when you initiate shutdown from the instance. Valid values are 'stop', 'terminate'. Defaults to 'stop'.

#####`block_devices` 
*Optional* A list of block devices to associate with the instance. Accepts an array of hashes with the device name and volume size specified: 

~~~
block_devices => [
  {
    device_name  => '/dev/sda1',
    volume_size  => 8,
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

#### Type: ec2_securitygroup

##### `name
*Required* The name of the security group. This is the value of the AWS Name tag.

##### `region`
*Required* The region in which to launch the security group. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

##### `ingress`
*Optional* Rules for ingress traffic. Accepts an array.
 
##### `tags`
*Optional* The tags for the security group. Accepts a 'key => value' hash of tags.

##### `description`
*Required* A short description of the group.

##### `vpc`
*Optional* The VPC to which the group should be associated. Accepts the value of the Name tag for the VPC.


#### Type: elb_loadbalancer

#####`name`
*Required* The name of the load balancer. This is the value of the AWS Name tag.

#####`region`
*Required* The region in which to launch the load balancer. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

#####`listeners`
*Required* The ports and protocols the load balancer listens to. Accepts an array of the following values:
  * protocol
  * load_balancer_port
  * instance_protocol
  * instance_port

#####`tags`
*Optional* The tags for the load balancer. Accepts a 'key => value' hash of tags.

#####`subnets`
*Optional* The subnet in which the load balancer should be launched. Accepts an array of subnet names, i.e., the Name tags on the subnets.


#####`security_groups` 
*Optional* The security groups to associate with the load balancer (VPC only). Accepts an array of security group names, i.e., the Name tag on the security groups.

#####`availability_zones`
*Optional* The availability zones in which to launch the load balancer. Accepts an array on availability zone codes. For valid availability zone codes, see [AWS Regions and Availability Zones](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html).

#####`instances`
*Optional* The instances to associate with the load balancer. Accepts an array of names, i.e., the Name tag on the instances.

#####`scheme`
*Optional* Whether the load balancer is internal or public facing. Valid values are 'internal', 'internet-facing'. Default value is 'internet-facing' and makes the load balancer publicly available.

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
*Optional* The actions to trigger when the alarm triggers. This parameter currently supports only named scaling policies.

#### Type: ec2_autoscalinggroup

##### `name`
*Required* The name of the auto scaling group. This is the value of the AWS Name tag.

##### `min_size`
*Required* The minimum number of instances in the group. 

##### `max_size`
*Required* The maximum number of instances in the group.

##### `region`
*Required* The region in which to launch the instances. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

#####`launch_configuration`
*Required* The name of the launch configuration to use for the group. This is the value of the AWS Name tag.

##### `availability_zones`
*Required* The availability zones in which to launch the instances. Accepts an array of availability zone codes. For valid availability zone codes, see [AWS Regions and Availability Zones](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html).

##### `subnets`
*Optional* The subnets to associate with the autoscaling group.

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
*Required* The security groups to associate with the instances. Accepts an array of security group names, i.e., the Name tags on the security groups.

#####`user_data`
*Optional* User data script to execute on new instances.

#####`key_name`
*Optional* The name of the key pair associated with this instance.

#####`region`
*Required* The region in which to launch the instances. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

#####`instance_type`
*Required* The type to use for the instances. See [Amazon EC2 Instances](http://aws.amazon.com/ec2/instance-types/) for available types.

#####`image_id`
*Required* The image id to use for the instances. For more information, see AWS documentation on finding your [Amazon Machine Image (AMI)](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/finding-an-ami.html). 

#####`vpc`
*Optional* A hint to specify the VPC. This is useful when detecting ambiguously named security groups that might exist in different VPCs, such as 'default'.

#### Type: ec2_scalingpolicy

#####`name`
*Required* The name of the scaling policy. This is the value of the AWS Name tag.

#####`scaling_adjustment`
*Required* The amount to adjust the size of the group by. Valid values depend on `adjustment_type` chosen. See [AWS Dynamic Scaling](http://docs.aws.amazon.com/AutoScaling/latest/DeveloperGuide/as-scale-based-on-demand.html) documentation. 

#####`region`
*Required* The region in which to launch the policy. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

#####`adjustment_type`
*Required* The type of policy. Accepts a string specifying the policy adjustment type. For valid values, see AWS [Adjustment Type](http://docs.aws.amazon.com/AutoScaling/latest/APIReference/API_AdjustmentType.html) documentation. 

#####`auto_scaling_group
*Required* The name of the auto scaling group to attach the policy to. This is the value of the AWS Name tag.

#### Type: ec2_vpc

#####`name`
*Required* The name of the VPC. This is the value of the AWS Name tag.

#####`region`
*Optional* The region in which to launch the VPC. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

#####`cidr_block`
*Optional* The IP range for the VPC.

#####`dhcp_options`
*Optional* The name of DHCP option set to use for this VPC.

#####`instance_tenancy` 
*Optional* The supported tenancy options for instances in this VPC. Valid values are 'default', 'dedicated'. Defaults to 'default'.

#####`tags`
*Optional* The tags to assign to the VPC. Accepts a 'key => value' hash of tags.

#### Type: ec2_vpc_customer_gateway

#####`name`
*Required* The name of the customer gateway. This is the value of the AWS Name tag.

#####`ip_address`
*Required* The IPv4 address for the customer gateway. Accepts a valid IPv4 address.

#####`bgp_asn`
*Required* The Autonomous System Numbers for the customer gateway.

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
*Optional* The domain name for the DHCP options. Accepts any valid domain. 

#####`domain_name_servers` 
*Optional* A list of domain name servers to use for the DHCP options set. Accepts an array of domain server names. 

#####`ntp_servers
*Optional* A list of NTP servers to use for the DHCP options set. Accepts an array of NTP server names.

#####`netbios_name_servers`
*Optional* A list of netbios name servers to use for the DHCP options set. Accepts an array.

#####`netbios_node_type`
*Optional* The netbios node type. Valid values are '1', '2', '4', '8'. Defaults to '2'.


#### Type: ec2_vpc_internet_gateway

#####`name`
*Required* The name of the internet gateway. This is the value of the AWS Name tag.
 
#####`tags`
*Optional* Tags to assign to the internet gateway. Accepts a 'key => value' hash of tags.

#####`region`
*Optional* The region in which to launch the internet gateway. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

#####`vpc`
*Optional* The vpc to assign this internet gateway to.


#### Type: ec2_vpc_routetable

#####`name`
*Required* The name of the route table. This is the value of the AWS Name tag.

#####`vpc`
*Optional* VPC to assign the route table to.

#####`region`
*Optional* The region in which to launch the route table. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

#####`routes`
*Optional* Individual routes for the routing table. Accepts an array of 'destination_cidr_block' and 'gateway' values:
 
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
*Optional* VPC to assign the subnet to.

#####`region`
*Required* The region in which to launch the subnet. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

#####`cidr_block`
*Optional* The IP address range for the subnet.

#####`availability_zone`
*Optional* The availability zone in which to launch the subnet.

#####`tags`
*Optional* Tags to assign to the subnet. Accepts a 'key => value' hash of tags.

#####`route_table`
The route table to attach to the subnet.

#####`region`
*Optional* Region in which to launch the route table. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

#####`routes`
*Optional* Individual routes for the routing table. Accepts an array of 'destination_cidr_block' and 'gateway' values:


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
*Required* The VPN gateway to attach to the VPN.

#####`customer_gateway`
*Required* The customer gateway to attach to the VPN.

#####`type`
*Optional* The type of VPN gateway. The only currently supported value --- and the default --- is 'ipsec.1'.

#####`routes` 
*Optional* The list of routes for the VPN. Valid values are IP ranges like: `routes           => ['0.0.0.0/0']`

#####`static_routes`
*Optional* Whether or not to use static routes. Valid values are 'true', 'false'. Defaults to 'true'.

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
*Required* The VPN to attach the VPN gateway to.

#####`region`
*Required* The region in which to launch the VPN gateway. For valid values, see [AWS Regions](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region).

#####`availability_zone`
*Optional* The availability zone in which to launch the VPN gateway.

#####`type`
*Optional* The type of VPN gateway. The only currently supported value --- and the default --- is 'ipsec.1'.

#### Type: route53*

The route53 types set up various types of Route53 records:

* route53_a_record
Sets up a Route53 DNS record. 

* route53_aaaa_record
Sets up a Route53 DNS AAAA record.

* route53_cname_record
Sets up a Route53 CNAME record.

* route53_mx_record
Sets up a Route53 MX record.

* route53_ns_record
Sets up a Route53 DNS record.

* route53_spf_record
Sets up a Route53 SPF record.

* route53_srv_record
Sets up a Route53 SRV record.

* route53_txt_record
Sets up a Route53 TXT record.

* route53_zone
Sets up a Route53 DNS zone.

All Route53 record types use the same parameters:

#####`zone`
*Required* The zone associated with this record.

#####`name`
*Required* The name of DNS record.

#####`ttl`
*Optional* The time to live for the record. Accepts an integer.
 
#####`values`
*Required* The values of the record. Accepts an array.

#####`name`
*Required* The name of DNS zone group. This is the value of the AWS Name tag.

#### Type: route53_zone

#####`name`
*Required* The name of DNS zone group. This is the value of the AWS Name tag.


##Limitations

This module requires Ruby 1.9 or later and is only tested on Puppet
versions 3.4 and later.

At the moment this module only supports a few of the resources
in the AWS API. These resources also exist a bit outside the
normal host level resources like `package`, `file`, `user`, etc. We're
really interested to see how people use these new resources, and what
else you would like to be able to do with the module.
