# Auditing Security Groups

One use case for the Puppet AWS module is to audit the state of specified
resources in AWS. The wide range of tools using the AWS API means that
sometimes you just want to be alerted that something has changed.

## What

This example first creates a security group called `test-sg` in the
`sa-east-1` region. We then run Puppet in noop, which rather than
applying changes will simply report on out-of-sync resources.

## How

With the module installed as described in the README, from this
directory run:

    puppet apply init.pp

This creates the security group. We can see that by running:

    puppet resource ec2_securitygroup test-sg

Which should return:

~~~puppet
c2_securitygroup { 'test-sg':
  ensure      => 'present',
  description => 'Security group for audit',
  ingress     => [{'security_group' => 'test-sg'}],
  region      => 'sa-east-1',
}
~~~

Next let's run our noop command. Note that we're saving details of the
run to as a file called `lastrun` and then executing a shell script which
checks that file for out-of-sync resources.

    puppet apply init.pp --noop --test --lastrunfile lastrun --postrun_command='./count_out_of_sync_resources.sh'

Because we're in sync this should run cleanly and exit with a 0 status
code.

Now let's change something, either log into the AWS console and change one of
the resource properties or just delete the group completely. You could
imagine this simulating a change made by someone from another
department, not realising that this security group was in use.

    puppet resource ec2_securitygroup test-sg region=sa-east-1 ensure=absent

And finally run the noop command again:

    puppet apply init.pp --noop --test --lastrunfile lastrun --postrun_command='./count_out_of_sync_resources.sh'

This time the command should exit with a non-zero status code. The
status code represents the number of resources that are out of sync.

    echo $?

## Discussion

Depending on your use case, it may be easier to use Puppet without noop,
in which case as well as telling you about the missing security group
Puppet could have re-created it for you. This really depends on what
other tools you're using and how different teams work together.

The main point of this example is to show that using the Puppet AWS
module isn't an all or nothing affair. You could use it alongside other
tools and slowly roll out support across an existing AWS setup.

Note also that the bash script in `count_out_of_sync_resources.sh` is
very simple. You could expand this to print a more useful error message
to provide more context or to output something like Nagios plugin
format for integration with a monitoring system.
