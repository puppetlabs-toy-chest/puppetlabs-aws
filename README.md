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

First, set a couple of environment variables with your AWS credentials.

```
export AWS_ACCESS_KEY_ID=your_access_key_id
export AWS_SECRET_ACCESS_KEY=your_secret_access_key
```

Running the sample code with Puppet apply:

```bash
puppet apply tests/init.pp --modulepath ../ --test
```

To destroy the resources run the following:

```bash
puppet apply tests/delete.pp --modulepath ../ --test
```

Mote that due to dependencies between resources and the time taken to
transition state this currently requires multiple runs to complete.


## Tesiting

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
