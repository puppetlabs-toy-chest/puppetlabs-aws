#!/bin/bash

[ -f /opt/boxen/env.sh ] && source /opt/boxen/env.sh

# Test if we can run inside bundler
OUTPUT=$(bundle exec puppet --version)

if [[ $? == 0 ]]; then
  bundle exec puppet apply tests/$1 --modulepath ../../../
else
  puppet apply tests/$1 --modulepath ../../../
fi
