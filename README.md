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
```
