####Table of Contents

1. [Overview](#overview)
2. [Description - What the module does and why it is useful](#module-description)
3. [Setup - Getting started](#setup)
4. [Usage - Configuration options and additional functionality](#usage)
5. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)

##Overview

Puppet module for managing Amazon Web Services (AWS) resources to build out cloud infrastructure.

[![Puppet
Forge](http://img.shields.io/puppetforge/v/puppetlabs/aws.svg)](https://forge.puppetlabs.com/puppetlabs/aws) [![Build
Status](https://travis-ci.org/puppetlabs/puppetlabs-aws.svg?branch=master)](https://travis-ci.org/puppetlabs/puppetlabs-aws)

##Description

Amazon Web Services exposes a powerful API for creating and managing
its Infrastructure as a Service platform. This module
allows you to drive that API using Puppet code. In the simplest case
this allows you to create new EC2 instances from Puppet code, but more
importantly it allows you to describe your entire AWS infrastructure and
to model the relationships between different components.

##Setup

The module relies on the Amazon AWS Ruby SDK, so first install this. The
SDK is available as a gem so install it into the same Ruby as used by
Puppet.

    gem install aws-sdk-core

We also use the retries library so install that with:

    gem install retries

If you're running Puppet Enterprise you need to install the gems using
the following, so it can be used by the Puppet Enterprise Ruby.

    /opt/puppet/bin/gem install aws-sdk-core retries

And if you're running [Puppet
Server](https://github.com/puppetlabs/puppet-server) you need to
 make the gem available to JRuby with:

    /opt/puppet/bin/puppetserver gem install aws-sdk-core retries

Once the gem is installed you will need to restart the puppet-server:

    service pe-puppetserver restart

Finally you need to set a few environment
variables for your AWS access credentials.

```
export AWS_ACCESS_KEY_ID=your_access_key_id
export AWS_SECRET_ACCESS_KEY=your_secret_access_key
```

Alternatively, you can place the credentials in a file at
~/.aws/credentials based on the following template:

```yaml
[default]
aws_access_key_id = your_access_key_id
aws_secret_access_key = your_secret_access_key
```

If you're running the examples in AWS you can instead use [IAM](http://aws.amazon.com/iam/).
Simply assign the correct role to the instance from which you're running
the examples. We'll provide more details of the exact profiles for
different Puppet resources in the future.

And finally you can install the module with:

```bash
puppet module install puppetlabs-aws
```

### A note on regions

By default the module will look through all regions in AWS when
determining if something is available. This can be a little slow. If you
know what you're doing you can speed things up by targeting a single
region using an environment variable.

```bash
export AWS_REGION=eu-west-1
```

##Usage

### Using the DSL

Let's start with an example. Let's aim to create the following simple
stack in AWS.

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

Running the provided sample code with Puppet apply:

```bash
puppet apply tests/create.pp --test
```

If you want to try this out from this directory without installing the
module with `puppet module` or similar you can run the following:

```bash
puppet apply tests/create.pp --modulepath ../ --test
```

To destroy the resources created by the above you can run the following:

```bash
puppet apply tests/destroy.pp --test
```

The [examples](examples/) directory contains other examples which should give an
idea of what's possible.

### From the command line

The module also has basic `puppet resource` support, so for example the
following will list all the security groups:

```bash
puppet resource ec2_securitygroup
```

We can also create new resources:

```bash
puppet resource ec2_securitygroup test-group ensure=present description="test description" region=us-east-1
```

and then destroy them, all from the command line:

```bash
puppet resource ec2_securitygroup test-group ensure=absent region=sa-east-1
```

##Reference

The following shows each of the new types along with a full list of
their parameters.

### ec2_instance

```puppet
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
```

### ec2_securitygroup

```puppet
ec2_securitygroup { 'name-of-group':
  ensure      => present,
  region      => 'us-east-1',
  description => 'a description of the group',
  ingress     => [{
    protocol => 'tcp',
    port     => 80,
    cidr     => '0.0.0.0/0',
  },{
    security_group => 'other-security-group',
  }],
  tags        => {
    tag_name => 'value',
  },
}
```

### elb_loadbalancer

```puppet
elb_loadbalancer { 'name-of-load-balancer':
  ensure             => present,
  region             => 'us-east-1',
  availability_zones => ['us-east-1a', 'us-east-1b'],
  instances          => ['name-of-instance', 'another-instance'],
  security_groups    => ['name-of-security-group'],
  listeners          => [{
    protocol => 'tcp',
    port     => 80,
  }],
  tags               => {
    tag_name => 'value',
  },
}
```

##Limitations

At the moment this module only supports a small number of the resources
in the AWS API. These resources also exist a little bit outside the
normal host level resources like `package`, `file`, `user`, etc. We're
really interested to see how people use these new resources, and what
else you would like to be able to do with the module.

Note that this module also requires at least Ruby 1.9 and is only tested on Puppet
versions from 3.4. If this is too limiting please let us know.
