# Auditing Security Groups


## What


## How

With the module installed as described in the README, from this
directory run:

    puppet apply init.pp

    puppet apply init.pp --noop --test --lastrunfile lastrun --postrun_command=./count_out_of_sync_resources.sh

## Discussion
