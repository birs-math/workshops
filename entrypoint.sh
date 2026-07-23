#!/bin/bash
set -e

source /etc/profile.d/rvm.sh

echo
echo "Welcome to OS:"
uname -v
cat /etc/issue
sed -i -e 's/mesg n .*true/tty -s \&\& mesg n/g' ~/.profile


echo
echo "Setting system timezone..."
export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
echo "tzdata tzdata/Areas select America" > /tmp/tz.txt
echo "tzdata tzdata/Zones/America select Edmonton" >> /tmp/tz.txt
debconf-set-selections /tmp/tz.txt
rm /etc/timezone
rm /etc/localtime
dpkg-reconfigure --frontend noninteractive tzdata

echo
echo "Ruby version:"
ruby -v

echo
echo "Node version:"
node --version

echo
echo "Yarn version:"
yarn --version

echo
# The rubygems dir is a persisted volume. On a host whose volume predates this
# Ruby (e.g. staging/prod carried a 2.7.8 gemset), the 3.2.8 gemset bin/ starts
# empty, so `gem install bundler` writes a bundle wrapper whose shebang points
# at a gemset-local ruby that was never created -> exec ruby: not found (exit
# 127) at boot. Ensure the gemset ruby wrapper exists before installing bundler.
echo "Ensuring rvm gemset ruby wrapper..."
mkdir -p /usr/local/rvm/gems/ruby-3.2.8/bin
ln -sf /usr/local/rvm/rubies/ruby-3.2.8/bin/ruby /usr/local/rvm/gems/ruby-3.2.8/bin/ruby

echo
echo "Installing bundler..."
/usr/local/rvm/bin/rvm-exec 3.2.8 gem install bundler -v 2.4.22

echo
echo "Bundle install..."
su - app -c "cd /home/app/workshops; /usr/local/rvm/bin/rvm-exec 3.2.8 bundle install"

if [ ! -d "${GEM_HOME}/gems" ]; then
  echo
  echo "Gems not found in $GEM_HOME!"
  echo
  exit
fi

echo
echo "Changing to non-root file permissions..."
chown app:app -R /usr/local/rvm/gems

echo
echo "Running migrations..."
/usr/local/rvm/bin/rvm-exec 3.2.8 bundle exec rails db:migrate


if [ ! -e /home/app/workshops/tmp ]; then
  mkdir /home/app/workshops/tmp
  mkdir -p /home/app/workshops/vendor/cache
fi
chown app:app -R /home/app/workshops

echo
echo "Compiling Assets..."
su - app -c "cd /home/app/workshops; yarn install"
su - app -c "cd /home/app/workshops; RAILS_ENV=production SECRET_KEY_BASE=token bundle exec rake assets:precompile --trace"
su - app -c "cd /home/app/workshops; yarn"

#echo
echo
echo "Starting web server..."
/usr/local/rvm/bin/rvm-exec 3.2.8 bundle exec passenger start #--min-instances 2
