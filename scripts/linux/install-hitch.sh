#!/bin/bash

#remove the lock
set +e
sudo rm /var/lib/dpkg/lock > /dev/null
sudo rm /var/cache/apt/archives/lock > /dev/null
sudo dpkg --configure -a
set -e

sudo apt-get update -y
sudo apt-get -y install libev4 libev-dev gcc make git libev-dev libssl-dev automake python-docutils flex bison
cd /tmp
sudo rm -rf hitch
sudo git clone https://github.com/varnish/hitch.git hitch
cd hitch
./bootstrap 
./configure
sudo make install
cd ..
sudo rm -rf hitch

#make sure comet folder exists
sudo mkdir -p /opt/hitch

#initial permission
#sudo chown -R $USER /etc/init
sudo chown -R $USER /opt/hitch

#create non-privileged user
sudo useradd hitch || :