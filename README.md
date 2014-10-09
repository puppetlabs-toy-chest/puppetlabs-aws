Puppet module for managing AWS resources to build out infrastructure.

> Note that this repository contains a work-in-progress proof of
> concept.

[![Build
Status](https://magnum.travis-ci.com/puppetlabs/puppetlabs-aws.svg?token=RqtxRv25TsPVz69Qso5L&branch=master)](https://magnum.travis-ci.com/puppetlabs/puppetlabs-aws)

## Intention

Use the Puppet DSL to provision resources in AWS. To begin with we're
targetting the following simple stack comprising EC2 instances, EC2
security groups and ELB load balancers.

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

## Usage

First, set a few environment variables with your AWS credentials.

```
export AWS_ACCESS_KEY_ID=your_access_key_id
export AWS_SECRET_ACCESS_KEY=your_secret_access_key
```

Running the sample code with Puppet apply:

```bash
puppet apply tests/create.pp --modulepath ../ --test
```

To destroy the resources created by the above you can run the following:

```bash
puppet apply tests/destroy.pp --modulepath ../ --test
```

The tests directory contains other examples as well which should give an
idea of what's possible. Note in particular the master/agent setup with
EC2 API based autosigning.

### A note on regions

By default the module will look through all regions in AWS when
determining if something is available. This can be a little slow. If you
know what you're doing you can speed things up by targetting a single
region using an environment variable.

```bash
export AWS_REGION=eu-west-1
```

### Puppet resource support

The module also has basic `puppet resource` support, so for instance the
following will list all the security groups:

```bash
puppet resource ec2_securitygroup
```

We can also create new resources:

```bash
puppet resource ec2_securitygroup test-group ensure=present description="test description" region=sa-east-1
```

and then destroy them, all from the command line:

```bash
puppet resource ec2_securitygroup test-group ensure=absent region=sa-east-1
```

### Pegasus support

See the contrib folder for an example EC2 inventory script for pegasus.

### Puppet Cloud command

As an experiment we currently have an extention of the `puppet` command,
called puppet cloud, that exposes the typical actions. For instance you
can list all your ec2_instances (or other types):

```bash
puppet cloud list ec2_instance
```

Produce the dot files describing the resouces and relationships for a
given manifest.

```bash
puppet cloud graph tests/create.pp
```

An apply a given manifest.

```bash
puppet cloud apply tests/create.pp
```

Note that this currently only works when run from the root of this
project, but is included as a way of helping design the eventual user
interface.

## Testing

First you'll need to install the dependencies:

```bash
bundle install --path .bundle/gems
```

The running the tests once is as simple as:

```bash
bundle exec rake spec
```

If you're working on the module you may find having the tests run
whenever you change any code useful, in which case run:

```bash
bundle exec guard
```

### Acceptance tests

Given the nature of this project a small acceptance testing framework is
included in the `acceptance` directory. This is a small clojure
application which makes assertions agains the AWS API that the resources
we think we're creating are really there. Running this requires the
above mentioned environment variables and should work with:

```bash
lein test
```
