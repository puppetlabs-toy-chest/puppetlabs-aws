Integration Tests
========================

This folder contains integration tests for the puppetlabs-aws project. These tests were originally written by the QA team at Puppet Labs and is actively maintained by the QA team. Feel free to contribute tests to this folder as long as they are written with [Beaker-RSpec](https://github.com/puppetlabs/beaker-rspec) and follow the guidelines below.

## Integration?

The puppetlabs-aws project already contains RSpec tests and you might be wondering why there is a need to have a set of tests separate from those tests. At Puppet Labs we define an "integration" test as:

>Validating the system state and/or side effects while completing a complete life cycle of user stories using a system. This type of test crosses the boundary of a discrete tool in the process of testing a defined user objective that utilizes a system composed of integrated components.  What this means for this project is that we will install and configure all infrastructure used in a real-world PE environment.

## Integration Test Requirements
The following is a list of requirements to run these tests.
* access to a staging forge
* aws credentials file in the following location ~/.aws/credentials

