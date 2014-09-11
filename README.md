Puppet module for managing AWS resources to build out full stacks

> Note that this repository contains a work-in-progress proof of
> concept.

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
--ordering=manifest
```

Note the manifest ordering is a short term approach while we sort out
autorequire.

To destroy the resources run the following:

```bash
puppet apply tests/delete.pp --modulepath ../ --test
--ordering=manifest
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
