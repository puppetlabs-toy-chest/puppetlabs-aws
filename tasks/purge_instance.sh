#!/bin/bash

INSTANCE_ID=$PT_instance

CA_CERT='/etc/puppetlabs/puppet/ssl/certs/ca.pem'
CERT="/etc/puppetlabs/puppet/ssl/certs/$(/opt/puppetlabs/bin/puppet config print certname).pem"
CERT_KEY="/etc/puppetlabs/puppet/ssl/private_keys/$(/opt/puppetlabs/bin/puppet config print certname).pem"

echo "Searching for certname associated with $INSTANCE_ID"

CURL_RESULTS=`/opt/puppetlabs/bin/puppet-query \
--cacert=$CA_CERT \
--cert=$CERT \
--key=$CERT_KEY \
"fact_contents[certname] { path ~> [\"ec2_metadata\", \"instance-id\"] and value = \"$INSTANCE_ID\" }"`

PURGE_CERTNAME=`echo $CURL_RESULTS | grep certname | cut -d : -f2 | xargs | cut -d ' ' -f1`

# ugly but informative.
if [ -n $PURGE_CERTNAME ] && [ "$PURGE_CERTNAME" != "" ]; then
  echo "Found $PURGE_CERTNAME"
  /opt/puppetlabs/bin/puppet cert clean $PURGE_CERTNAME
  /opt/puppetlabs/bin/puppet node purge $PURGE_CERTNAME
  if [ $? -eq 0 ]; then
    echo "$PURGE_CERTNAME purged and cleaned"
    EXITVAL=0
  else
    echo "Erroring purging $PURGE_CERTNAME"
    EXITVAL=100
  fi
else
  echo "No certname associated with $INSTANCE_ID"
  EXITVAL=200
fi

exit $EXITVAL
