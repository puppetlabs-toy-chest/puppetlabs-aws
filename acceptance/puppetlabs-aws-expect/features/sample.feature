Feature: AWS Puppet Module
  A simple test of create and destroy using the AWS provider

  Scenario: Creating AWS resources
    Then we should not find the resources in AWS
    When we run puppet with 'create.pp'
    And after 1 seconds
    Then we should find the created resources in AWS
    When we run puppet with 'destroy.pp'
    And after 1 seconds
    Then we should not find the resources in AWS
