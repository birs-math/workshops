#!/bin/bash
set -e

source /etc/profile.d/rvm.sh

echo
echo "Running que..."
/usr/local/rvm/bin/rvm-exec 3.2.8 bundle exec que
