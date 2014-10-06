#!/bin/bash

[ -f /opt/boxen/env.sh ] && source /opt/boxen/env.sh

puppet apply tests/$1 --modulepath ../../../
