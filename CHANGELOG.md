## 2015-03-25 - Supported Version 1.0.0

This release includes:

* Integration with VPC for Autoscaling groups, instances and security groups
* Support for managing Elastic IP addresses
* Additional DSN types for the Route53 support
* Detailed documentation on the properties of each type
* Better error messaging in case of AWS failures
* Extensive validation of types


## 2015-02-26 - Version 0.3.0

This release includes support for:

* Autoscaling groups
* VPC (Virtual Private Cloud - the AWS internal network)
* Route53 DNS

This also improves the other resources (instances, security groups and
elastic load balancers), includes examples of the news resources and
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
