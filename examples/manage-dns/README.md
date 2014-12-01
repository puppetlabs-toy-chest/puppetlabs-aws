# DNS

This example demonstrates using the Route53 resources to manage DNS
records.

## What

For this example we'll create a Zone, along with an A record. We'll also
show how to list current records of the supported types.

The Zone we're creating is for `puppetlabs.com`, although when you run
the example you may want to change that to your own domain.

## How

With the module installed as described in the README, from this
directory run:

    puppet apply init.pp --test


This should create a ROute53 zone and an A record for
`local.puppetlabs.com` pointing to 127.0.0.1.

You should be see the zone when you run:

    puppet resource route53_zone

This should output the following, maybe along with other domains you're
already managing.

```puppet
route53_zone { 'puppetlabs.com.':
  ensure => 'present',
}
```

And to list the A records:

    puppet resource route53_a_record

Which should return:

```puppet
route53_a_record { 'local.puppetlabs.com.':
  ensure => 'present',
  ttl    => '3000',
  values => ['127.0.0.1'],
  zone   => 'puppetlabs.com.',
}
```

We can also list the automatically created NS records with:

    puppet resource route53_ns_record

Which should output something like:

```puppet
route53_ns_record { 'puppetlabs.com.':
  ensure => 'present',
  ttl    => '172800',
  values => ['ns-1254.awsdns-28.org.', 'ns-1922.awsdns-48.co.uk.', 'ns-806.awsdns-36.net.', 'ns-103.awsdns-12.com.'],
  zone   => 'puppetlabs.com.',
}
```

Finally we can delete the A record followed by the Zone:

    puppet resource route53_a_record local.puppetlabs.com. zone=puppetlabs.com. values=127.0.0.1 ttl=3000 ensure=absent
    puppet resource route53_zone puppetlabs.com. ensure=absent

