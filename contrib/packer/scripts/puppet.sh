#!/bin/bash

# Install language locale as without can
# interfere with package installation
sudo apt-get install language-pack-en -y

# Upgrade everything
sudo apt-get update
sudo apt-get upgrade -y

# Install puppet from official packages
cd /tmp
wget https://apt.puppetlabs.com/puppetlabs-release-trusty.deb
sudo dpkg -i puppetlabs-release-trusty.deb
sudo apt-get update

sudo apt-get install puppet -y
