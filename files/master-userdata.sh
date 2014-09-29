#!/bin/bash

apt-get update
apt-get install puppetmaster-passenger -y

puppet config set dns_alt_names puppet,$(facter fqdn) --section main
puppet config set certname $(curl -s http://169.254.169.254/latest/meta-data/instance-id) --section agent

sed -i /etc/default/puppet -e 's/START=no/START=yes/'

service apache2 restart

puppet resource service puppet ensure=running enable=true
