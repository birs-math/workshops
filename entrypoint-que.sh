#!/bin/bash
set -e

source /etc/profile.d/rvm.sh

echo
echo "Running que..."
/usr/local/rvm/bin/rvm-exec 2.7.7 bundle exec que
