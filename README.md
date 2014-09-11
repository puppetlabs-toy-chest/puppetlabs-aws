Puppet module for managing AWS resources to build out full stacks

> Note that this repository contains a work-in-progress proof of
> concept.

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
