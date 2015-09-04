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
