route53_zone { 'puppetlabs.com.':
  ensure => absent,
}

route53_a_record { 'local.puppetlabs.com.':
  ensure => absent,
  before => Route53_zone['puppetlabs.com.'],
}

route53_txt_record { 'local.puppetlabs.com.':
  ensure => absent,
  before => Route53_zone['puppetlabs.com.'],
}
