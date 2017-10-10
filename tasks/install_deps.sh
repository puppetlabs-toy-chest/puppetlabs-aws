#!/bin/bash

/opt/puppetlabs/bin/puppet resource package retries ensure=present provider=puppet_gem
/opt/puppetlabs/bin/puppet resource package aws-sdk ensure=present provider=puppet_gem
