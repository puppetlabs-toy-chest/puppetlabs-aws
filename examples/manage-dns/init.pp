route53_zone { 'puppetlabs.com.':
  ensure => present,
}

route53_a_record { 'local.puppetlabs.com.':
  ensure => present,
  zone   => 'puppetlabs.com.',
  ttl    => 3000,
  values => ['127.0.0.1'],
}

