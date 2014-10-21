hiera_include('classes')

package { ['rake', 'serverspec']:
  ensure   => installed,
  provider => gem,
}

user { 'garethr':
  ensure     => present,
  managehome => true,
  groups     => ['sudo'],
}

ssh_authorized_key { 'garethr@pro':
  ensure  => present,
  key     => 'AAAAB3NzaC1yc2EAAAADAQABAAABAQCrSkTpqpXM4pU7x6cxMCvElx7og8Gx8mPLtG6+Gn4JIyVdqAIYnFccAduMOgI0492/RgSOTOS9GtT1HXfFrIWDPqCj3/dXJErwr2BzjFS9jJI0x2epB6T4iAk4zij3bjjpkWFQonS/57iBTuV+RNDk/aeDC8mbSfreQYITujjtCtBahbDSC6F7uOp0Ckua1YO6+kRZKBa3Z42LGPjsvtyzeYSVNkSnzT3HKESUImDiM7ewZ9CAiQbEsjEYO7ZJO3Lkx+frVyq6UApPvywEGyywEaejoxd3d9NhMmCNEl4TOfR6J6/jfEa9ZuGoXqQKMCmiiUMwXyIwF2Z4Y0mG8YEJ',
  target  => '/home/garethr/.ssh/authorized_keys',
  user    => 'garethr',
  type    => 'ssh-rsa',
  require => User['garethr'],
}

sudo::conf { 'garethr':
  priority  => 30,
  content   => 'garethr ALL=(ALL) NOPASSWD:ALL',
}
