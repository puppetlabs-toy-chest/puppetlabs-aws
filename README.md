Puppet module for managing AWS resources to build out infrastructure.

> Note that this repository contains a work-in-progress proof of
> concept.

[![Build
Status](https://magnum.travis-ci.com/puppetlabs/puppetlabs-aws.svg?token=RqtxRv25TsPVz69Qso5L&branch=master)](https://magnum.travis-ci.com/puppetlabs/puppetlabs-aws)

## Intention

Use the Puppet DSL to provision resources in AWS. The begin with we're
targetting the following simple stack.

```
                          WWW
                           +
                           |
          +----------------|-----------------+
          |                |                 |
          |     +----------v-----------+     |
    lb-sg |     |         lb-1         |     |
          |     +----+------------+----+     |
          |          |            |          |
          +----------|------------|----------+
          +----------|------------|----------+
          |     +----v----+  +----v----+     |
          |     |         |  |         |     |
          |     |         |  |         |     |
   web-sg |     |  web-1  |  |  web-2  |     |
          |     |         |  |         |     |
          |     |         |  |         |     |
          |     +----+----+  +----+----+     |
          +----------|------------|----------+
          +----------|------------|----------+
          |     +----v----+       |          |
          |     |         |       |          |
          |     |         |       |          |
    db-sg |     |  db-1   <-------+          |
          |     |         |                  |
          |     |         |                  |
          |     +---------+                  |
          +----------------------------------+
```

## Usage

First, set a few environment variables with your AWS credentials.

```
export AWS_ACCESS_KEY_ID=your_access_key_id
export AWS_SECRET_ACCESS_KEY=your_secret_access_key
export AWS_REGION=your_chosen_region
```

Running the sample code with Puppet apply:

```bash
puppet apply tests/init.pp --modulepath ../ --test
```

To destroy the resources run the following:

```bash
puppet apply tests/delete.pp --modulepath ../ --test
```

Note that due to dependencies between resources and the time taken to
transition state this currently requires multiple runs to complete.

## Puppet resource support

The module also has basic `puppet resource` support, so for instance the
following will list all the security groups:

```bash
puppet resource ec2_securitygroup
```

We can also create new resources:

```bash
puppet resource ec2_securitygroup test-group ensure=present
description="test description" region=sa-east-1
```

and then destroy them, all from the command line:

```bash
puppet resource ec2_securitygroup test-group ensure=absent
region=sa-east-1
```

## Testing

First you'll need to install the dependencies:

```bash
bundle install
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
