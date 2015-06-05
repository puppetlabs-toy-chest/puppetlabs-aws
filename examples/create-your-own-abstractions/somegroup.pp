define somegroup(
  $ami,
  $region,
  $type = 't1.micro',
  $ensure = 'present',
) {
  # For a more complex example we could validate the
  # arguments using stdlib or the new future parser
  ec2_instance { ["${title}-1", "${title}-2"]:
    ensure          => $ensure,
    region          => $region,
    image_id        => $ami,
    security_groups => "${title}-sg",
    instance_type   => $type,
  }

  ec2_securitygroup { "${title}-sg":
    ensure      => $ensure,
    description => "group for ${title}",
    region      => $region,
  }

  # ec2_instance resources need to be deleted before the
  # associated security groups. In the case of ensure => present
  # the type automatically resolves the correct order
  if $ensure == 'absent' {
    Ec2_instance["${title}-1"] ~> Ec2_securitygroup["${title}-sg"]
    Ec2_instance["${title}-2"] ~> Ec2_securitygroup["${title}-sg"]
  }
}
