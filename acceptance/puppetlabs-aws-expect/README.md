# Acceptance tests for puppetlabs-aws

This is a pretty experimental approach to writing tests against the AWS
API. Including here to have a discussion about it's utility.

Currently it makes some pretty big assumptions about the state of the
entire AWS environment under test. If you're intrigued start in the
`test/clojure/puppetlabs_aws_expect/test.clj` file.

## Usage

If you want to run the tests as a one off just run:

```bash
lein test
```

If you're using them while developing the module then you can set them
to run whenever you change the (test) code with:

```bash
lein autoexpect
```
