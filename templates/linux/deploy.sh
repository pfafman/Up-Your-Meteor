#!/bin/bash

APP_NAME="<%= appName %>"
CHECK_WAIT_TIME=<%= deployCheckWaitTime %> 

# utilities
gyp_rebuild_inside_node_modules () {
  for npmModule in ./*; do
    cd $npmModule

    isBinaryModule="no"
    # recursively rebuild npm modules inside node_modules
    check_for_binary_modules () {
      if [ -f binding.gyp ]; then
        isBinaryModule="yes"
      fi

      if [ $isBinaryModule != "yes" ]; then
        if [ -d ./node_modules ]; then
          cd ./node_modules
          for module in ./*; do
            cd $module
            check_for_binary_modules
            cd ..
          done
          cd ../
        fi
      fi
    }

    check_for_binary_modules

    if [ $isBinaryModule = "yes" ]; then
      echo " > $npmModule: npm install due to binary npm modules"
      rm -rf node_modules
      if [ -f binding.gyp ]; then
        sudo npm install
        sudo node-gyp rebuild || :
      else
        sudo npm install
      fi
    fi

    cd ..
  done
}

rebuild_binary_npm_modules () {
  for package in ./*; do
    if [ -d $package/node_modules ]; then
      cd $package/node_modules
        gyp_rebuild_inside_node_modules
      cd ../../
    elif [ -d $package/main/node_module ]; then
      cd $package/node_modules
        gyp_rebuild_inside_node_modules
      cd ../../../
    elif [ -d $package ]; then # Meteor 1.3
      cd $package
        rebuild_binary_npm_modules
      cd ..
    fi
  done
}

revert_app (){
  if [[ -d old_app ]]; then
    sudo rm -rf app
    sudo mv old_app app
    sudo service $APP_NAME stop || :
    sudo service $APP_NAME start || :

    echo "Latest deployment failed! Reverted back to the previous version." 1>&2
    exit 1
  else
    echo "App did not pick up! Please check app logs." 1>&2
    exit 1
  fi
}

# logic
set -e

APP_DIR=/opt/$APP_NAME
TMP_DIR=${APP_DIR}/tmp
BUNDLE_DIR=${TMP_DIR}/bundle

echo "cd ${TMP_DIR}"
cd ${TMP_DIR}
sudo rm -rf bundle
sudo tar xvzf bundle.tar.gz > /dev/null
sudo chmod -R +x *
sudo chown -R ${USER} ${BUNDLE_DIR}

# setting up NPMs
cd ${BUNDLE_DIR}/programs/server
echo "Reinstall npm modules"

echo "Remove node_modules"
sudo rm -rf node_modules

echo "Fix Permissions to user ${USER}"
sudo chown -R ${USER} ~/.node-gyp
sudo chown -R ${USER} ~/.npm
sudo chown -R ${USER} *
sudo chmod 755 package.json
sudo chmod 755 npm-shrinkwrap.json

# echo "Remove node_modules (again?)"
# sudo rm -rf node_modules

echo "npm install"
npm install

cd /opt/$APP_NAME/

# remove old app, if it exists
if [ -d old_app ]; then
  sudo rm -rf old_app
fi

## backup current version
if [[ -d app ]]; then
  sudo mv app old_app
fi

sudo mv tmp/bundle app

# #wait and check
# echo "Waiting for MongoDB to initialize. (5 minutes)"
. /opt/$APP_NAME/config/env.sh
# wait-for-mongo ${MONGO_URL} 300000

# restart app
sudo service $APP_NAME stop || :
sudo service $APP_NAME start || :

echo "Waiting for $CHECK_WAIT_TIME seconds while app is booting up"

COUNTER=0
while [  $COUNTER -lt 10 ]; do
   echo The counter is $COUNTER
   let COUNTER=COUNTER+1
   sleep $CHECK_WAIT_TIME
   curl localhost:${PORT} && let COUNTER=10
done

echo "Checking is app booted or not?"
curl localhost:${PORT} || revert_app

# chown to support dumping heapdump and etc
sudo chown -R meteoruser app
