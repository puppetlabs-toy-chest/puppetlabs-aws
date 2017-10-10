#!/bin/bash

#set aws region to once provided

export AWS_REGION=$PT_region

if [ "$PT_name" != "" ]; then
  echo "Showing $PT_name in $PT_region"
  /opt/puppetlabs/bin/puppet resource ec2_vpc $PT_name
else
  echo "Showing all VPCs in $PT_region"
  /opt/puppetlabs/bin/puppet resource ec2_vpc
fi
