ec2_instance { [
  'lb-1',
  'lb-2',
  'app-1',
  'app-2',
  'app-3',
  'app-4',
  'app-5',
  'app-6',
  'app-7',
  'app-8',
  'app-9',
  'app-10',
]:
  ensure => absent,
  region => 'sa-east-1',
}
