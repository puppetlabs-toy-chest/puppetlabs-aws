# Unit Testing AWS Infrastucture

This example demonstrates using the standard Puppet testing tools to
test code in the AWS module.

## What

Note that in this example we're not actually creating any
infrastructure, we're just writing unit tests for our manifests using
[rspec-puppet](http://rspec-puppet.com/). We'll also check the code
against the puppet style guide using
[puppet-lint](http://puppet-lint.com/) and for any syntax errors using
[puppet-syntax](https://github.com/gds-operations/puppet-syntax).


## How

First, you'll need to install the testing dependencies using
[bundler](http://bundler.io/). We'll then use
[r10k](https://github.com/adrienthebo/r10k) to make the AWS module
available to the manifests under test.

    bundle install
    bundle exec r10k puppetfile install

With that all set up you should be able to run all of the tests:

    bundle exec rake test

This should output something like the following:

~~~
---> syntax:manifests
---> syntax:templates
---> syntax:hiera:yaml
/Users/garethr/.rvm/rubies/ruby-2.1.4/bin/ruby -S rspec
spec/hosts/arbiter_spec.rb

arbiter
  should compile into a catalogue without dependency cycles
  should contain exactly 2 Ec2_instance resources
  should contain Ec2_instance[web1] with region => "sa-east-1" and
instance_type => "t1.micro"
  should contain Ec2_instance[web2] with region => "sa-east-1" and
instance_type => "t1.micro"

Finished in 0.23166 seconds
4 examples, 0 failures
~~~

Note that if you prefer, you can run the lint, syntax, and spec tests
separately with individual commands:

    bundle exec rake lint
    bundle exec rake syntax
    bundle exec rake spec

See the [manifest under test](manifests/site.pp) and the
[accompanying Hiera data](spec/fixtures/hiera/test.yaml) for what we're
testing, and then take a look at the [tests
themselves](spec/hosts/arbiter_spec.rb).


## Discussion

One of the advantages of using Puppet to describe your infrastructure is
that you can take advantage of the existing tools, including testing
tools and support for syntax highlighting in editors like Vim or more advnaced functionality in IDEs like [Geppetto](https://docs.puppetlabs.com/geppetto/4.0/) and [Visual
Studio](https://visualstudiogallery.msdn.microsoft.com/a517bc05-258e-4010-be95-71bef6a10d3a).
