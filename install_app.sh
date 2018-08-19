#!/bin/bash

# Script to run on the deployed server when the code has been
# updated (or on first deployment)

ruby_version=`cat .ruby-version`
echo Installing Ruby $ruby_version
source /home/ubuntu/rbenv-init && rbenv install -s $ruby_version

echo Installing bundler
gem install --conservative bundler

echo Installing gems
bundle install

echo Installing JS packages
yarn install

echo Done!
