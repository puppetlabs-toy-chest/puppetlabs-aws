# Data Driven Manifests

This is a slightly advanced example, making use of the iteration
features available in the [future
parser](https://docs.puppetlabs.com/puppet/latest/reference/experiments_future.html).


## What

The provided diagram shows what this example will create, namely:

* 2 security groups, named web-sg and db-sg.
* 6 instances, split between the two security groups.

~~~
         +-------------------------------------------------+
         | +---------+ +---------+ +---------+ +---------+ |
         | |         | |         | |         | |         | |
 web-sg  | | web-1   | | web-2   | | web-3   | | web-4   | |
         | |         | |         | |         | |         | |
         | +---------+ +---------+ +---------+ +---------+ |
         +-------------------------------------------------+

         +-------------------------+
         | +---------+ +---------+ |
         | |         | |         | |
 db-sg   | | db-1    | | db-2    | |
         | |         | |         | |
         | +---------+ +---------+ |
         +-------------------------+
~~~

What we're really demonstrating is the use of data to drive our
infrastructure. At the top of the example manifest is the following:

~~~puppet
$instances = {
  'web' => 4,
  'db'  => 2,
}
~~~

The rest of the manifest uses this data to automatically generate the
puppet resources. If you increase the numbers, or add new types, and
re-run the manifest, the new security groups and instances will be
created.


## How

To run the examples, first install the module as described in the README.
Then run the following in this directory:

    puppet apply init.pp --test --parser future


## Discussion

This example shows one approach to using data to drive the structure of
your infrastructure, but other elements could obviously be pulled out
from the manifests and into a Hiera backend.

A known limitation of this specific code is that reducing the number of
instances, or removing a type from the hash won't result in those
instances being deleted.
