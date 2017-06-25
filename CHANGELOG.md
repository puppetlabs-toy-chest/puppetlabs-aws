## Supported Version 2.0.0

This release includes:
- Drop support for Puppet 3
- RDS extensions including snapshot restore and VPC support
- Support for managing EC2 volumes
- Support for SSD-based EBS volumes and made these the default for storage
- Early IAM (role, group, instance profile) and KMS support
- S3 bucket support with policy management
- ECS (service, task, role) support
- Support for CloudFormation

As well as following fixes and improvements:
- Initial internationalization support, including a Japanese README
- Acceptance test fixes and updates
- Public DNS resolution and hostname properties for VPC
- Support for private Route53 zones
- Remove securitygroup autorequire to allow circular dependencies
- Allow security group mutual peering
- Initial support for CloudFront
- Filter sensitive data during VCR recording
- Initial support for elbv2 load balancers
- Support for ELB listener modification
- Allow security group changes for ec2_instance
- Improve ELB enumeration performance
- Add visibility_timeout property to sqs_queue
- Launch configuration/block device mappings
- Health check management and insync property for ELB
- Replace read-only failures with warning
- Add alias_target property for Route53
- Retry for ELB request limits
- Add dns_name property to elb_loadbalancer
- Add block_device_mappings for launch_config type
- associate_public_ip_address for ec2 instances
- Dedicated tenancy for ec2 instances
- Tags support and additional properties for ec2_autoscalinggroup
- Remove default netbios_node_type value for ec2_vpc_dhcp_options

## Supported Version 1.4.0

This release includes:
- The set of instances that are associated with an ELB can now be modified.
- Added 'ssl_certificate_id' property to elb_loadbalancer.
- Added support for Debian 8.

As well as following fixes and improvements:
- Fixed issues related to the region property being displayed/returned incorrectly.
- Fixed parsing of puppetlabs_aws_configuration.ini
- Documentation improvements.
- Multiple test improvements.
- Rubocop updates.
- Fixed issue with elb_loadbalancer availability_zones synchronisation detection.
- Use the VPC's default subnet when none is specified on the ec2_instance.
- Enable puppet resource command usage across regions for ec2_vpc (and maybe others).
- Allow replacing the subnets of a elb_loadbalancer completely.
- Allow the use of elb_loadbalancer without availability zones, or using the default subnets (for each availability zone).
- Make default subnet choice idempotent for the ec2_instance resource.

## 2015-12-09 - Supported Version 1.3.0

This release includes:

* A new type and provider for managing SQS resources in AWS
* Support for using a credentials file for agents
* Support for PTR resources in Route53
* Allow snapshots to be used when mounting block devices for instances

As well as following fixes:

* Correctly handle timeouts when prefetching resources
* Fix error reporting for Route53 resources
* Correctly handle large sets of Route53 resource by paging through
  larger results sets
* Fixed an issue where routes that have don't have a gateway cause
  failures when loading routetables
* Correctly limit the association of EIPs to pending or running instances

Thanks to @jae2 @lattwood, @tamsky, Chris Pick, @cwood, @mikeslattery
@rfletcher and the folks at ServiceChannel for contributing to this release.


## 2015-09-04 - Supported Version 1.2.0

This release includes:

* The ability to manage a backup retention policy for RDS instances
* Improvements to the Route53 and ELB types to make them more robust

As well as following fixes:

* Support managing RDS instances in VPC subnets
* Updates to the IAM profile
* The Puppet Enterprise example now uses the correct download URL

Thanks to @aharden, @vazhnov, @rfletcher, @bashtoni, @claflico for
contributing to this release.


## 2015-07-22 - Supported Version 1.1.1

This release includes:

* Update to the metadata for the upcoming release of PE
* Update to the gem installation instructions in the README

## 2015-06-16 - Supported Version 1.1.0

This release includes:

* Support for managing RDS databases
* Instances now support assigning an IAM instance profile when created
* Large performance improvements for many resources, which should also
  allow for the management of larger AWS environments
* More examples and lots of small improvement to the documentation
* Updated IAM profile

Thanks to @jhoblitt, @daveseff and @pjfoley for contributing to this release.


## 2015-03-25 - Supported Version 1.0.0

This release includes:

* Integration with VPC for Autoscaling groups, instances and security groups
* Support for managing Elastic IP addresses
* Additional DNS types for the Route53 support
* Detailed documentation on the properties of each type
* Better error messaging in case of AWS failures
* Extensive validation of types


## 2015-02-26 - Version 0.3.0

This release includes support for:

* Autoscaling groups
* VPC (Virtual Private Cloud - the AWS internal network)
* Route53 DNS

This also improves the other resources (instances, security groups and
elastic load balancers), includes examples of the new resources and
expands the acceptance testing suite.

In total that's 19 types/providers, 16 of them new from the previous release.


## 2014-12-16 - Version 0.2.0

Builds on existing support for instances, security groups and load balancers, plus:

* Allows editing of existing security group ingress rules
* Exposes lots of information about instances to puppet resource
* Adds lots of new usage examples
* Adds a comprehensive acceptance testing suite


## 2014-11-03 - Version 0.1.0

Initial release includes nominal support for:

* EC2 Instances
* Security Groups
* Elastic Load Balancer (ELB)
