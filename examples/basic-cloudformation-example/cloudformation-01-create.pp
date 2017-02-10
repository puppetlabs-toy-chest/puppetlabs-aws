
cloudformation_stack { 's3-bucket-test':
  ensure        => updated,
  region        => 'us-west-2',
  template_url  => 'https://s3-us-west-2.amazonaws.com/cloudformation-templates-us-west-2/S3_Website_Bucket_With_Retain_On_Delete.template',
}
