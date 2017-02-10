
# Added some tags,
# added a WalrusLabel Parameter for BucketName,
# changed IndexDocument and ErrorDocument from *.html to *.htm,
# and DeletionPolicy to Delete.

cloudformation_stack { 's3-bucket-test':
  ensure        => updated,
  region        => 'us-west-2',
  tags          => {
    'product'     => 'S3',
    'environment' => 'test',
  },
  parameters    => { 'WalrusLabel' => "puppet-cloudformation-stack-bucket-name-walrus" },
  template_body => '
{
  "AWSTemplateFormatVersion": "2010-09-09",
  "Description": "AWS CloudFormation Sample Template S3_Website_Bucket_With_Delete_On_Delete: Sample template showing how to create a publicly accessible S3 bucket configured for website access with a deletion policy of retail on delete. **WARNING** This template creates an S3 bucket that will NOT be deleted when the stack is deleted. You will be billed for the AWS resources used if you create a stack from this template.",
  "Parameters": {
    "WalrusLabel": {
      "Type": "String",
      "Description": "The S3 Bucket name.",
      "AllowedPattern": "(?!-)[a-zA-Z0-9-.]{1,63}(?<!-)",
      "ConstraintDescription": "must be a valid s3 bucket String."
    }
  },
  "Resources": {
    "S3Bucket": {
      "Type": "AWS::S3::Bucket",
      "Properties": {
        "BucketName": { "Ref" : "WalrusLabel" },
        "AccessControl": "PublicRead",
        "WebsiteConfiguration": {
          "IndexDocument": "index.htm",
          "ErrorDocument": "error.htm"
        }
      },
      "DeletionPolicy": "Delete"
    }
  },
  "Outputs": {
    "WebsiteURL": {
      "Value": {
        "Fn::GetAtt": [
          "S3Bucket",
          "WebsiteURL"
        ]
      },
      "Description": "URL for website hosted on S3"
    },
    "S3BucketSecureURL": {
      "Value": {
        "Fn::Join": [
          "",
          [
            "https://",
            {
              "Fn::GetAtt": [
                "S3Bucket",
                "DomainName"
              ]
            }
          ]
        ]
      },
      "Description": "Name of S3 bucket to hold website content"
    }
  }
}',

}
