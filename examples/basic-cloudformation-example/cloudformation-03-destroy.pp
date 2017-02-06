
cloudformation_stack { 's3-bucket-test':
  ensure       => absent,
  region       => 'us-west-2',
}

