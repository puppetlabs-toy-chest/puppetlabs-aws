The following examples demonstrate using the AWS module to create
infrastructure.

* [Puppet Enterprise](puppet-enterprise/) - quickly startup a small
  Puppet Enterprise cluster using the AWS module
* [Managing DNS](manage-dns/) - manage DNS records in Amazon Route53
  using Puppet
* [Data Driven Manifests](data-driven-manifests/) - use the future
  parser to automatically generate resources based on a data structure
* [Hiera Example](hiera-example/) - store common information like region
  or AMI id in Hiera
* [Infrastructure as YAML](yaml-infrastructure-definition/) - describe an
  entire infrastructure stack in YAML, and use `create_resources` and
  Hiera to build your infrastructure
* [Auditing Resources](audit-security-groups/) - example of using
  Puppet's noop feature to Audit AWS resource changes and work alongside
  other tools
* [Unit Testing](unit-testing) - how to make use of the Puppet testing
  tools like rspec-puppet to test your AWS code
* [Virtual Private Cloud](vpc-example) - a simple example of using the
  Puppet DSL to manage a AWS VPC environment
