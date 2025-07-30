FROM ruby:3.0.0
ENV HOME /root
ENV RAILS_ENV development
ENV WORKSHOPS_HOME /home/app/workshops
ENV DEBIAN_FRONTEND noninteractive

# prevent gpg from using IPv6 to connect to keyservers
RUN mkdir -p ~/.gnupg && \
    echo "disable-ipv6" >> ~/.gnupg/dirmngr.conf

# Add required package repositories
RUN curl -sS https://raw.githubusercontent.com/yarnpkg/releases/gh-pages/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    curl -sS https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    curl -sL https://deb.nodesource.com/setup_16.x | bash -

# Install dependencies
RUN apt-get update -qq && \
    apt-get dist-upgrade --yes && \
    apt-get install --yes pkg-config apt-utils build-essential cmake automake && \
    apt-get upgrade --fix-missing --yes --allow-remove-essential -o Dpkg::Options::="--force-confold" && \
    apt-get install --yes --allow-downgrades nodejs=16.* tzdata udev locales curl git gnupg ca-certificates \
    libpq-dev wget libxrender1 libxext6 libsodium23 libsodium-dev yarn netcat-openbsd \
    gcc make zlib1g-dev sqlite3 libgmp-dev libc6-dev \
    shared-mime-info libssl-dev libreadline-dev libssh2-1-dev && \
    apt-get clean && apt-get autoremove --yes && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Use en_CA.utf8 as our locale
RUN locale-gen en_CA.utf8
ENV LANG en_CA.utf8
ENV LANGUAGE en_CA:en
ENV LC_ALL en_CA.utf8

# Install specific versions of RubyGems and Bundler
RUN gem update --system 3.3.26 && \
    gem install bundler -v 2.2.33

# Verify Ruby and Bundler are working
RUN ruby -v && bundle -v

# Create app user
RUN groupadd -r app && \
    useradd -r -g app -d /home/app -s /bin/bash app && \
    mkdir -p /home/app && \
    chown -R app:app /home/app

# Prepare app directory
ENV APP_HOME /home/app/workshops
RUN mkdir -p ${APP_HOME}/tmp && \
    mkdir -p ${APP_HOME}/vendor/cache && \
    mkdir -p /home/app/.config && \
    mkdir -p /home/app/.cache && \
    chown -R app:app ${APP_HOME} && \
    chown -R app:app /home/app/.config && \
    chown -R app:app /home/app/.cache

# Set bundler path to vendor/bundle to avoid permission issues
RUN mkdir -p ${APP_HOME}/vendor/bundle && \
    chown -R app:app ${APP_HOME}/vendor/bundle

# Copy application files
COPY --chown=app:app ./app ${APP_HOME}/app
COPY --chown=app:app ./bin ${APP_HOME}/bin
COPY --chown=app:app ./config ${APP_HOME}/config
COPY --chown=app:app ./db ${APP_HOME}/db
COPY --chown=app:app ./lib ${APP_HOME}/lib
COPY --chown=app:app ./log ${APP_HOME}/log
COPY --chown=app:app ./public ${APP_HOME}/public
COPY --chown=app:app ./storage ${APP_HOME}/storage
COPY --chown=app:app ./vendor ${APP_HOME}/vendor

# Copy essential files
COPY --chown=app:app \
 Gemfile \
 Gemfile.lock \
 package.json \
 yarn.lock \
 Rakefile \
 config.ru \
 ${APP_HOME}/

# Create empty config file
RUN touch ${APP_HOME}/config/app.yml && \
    chown app:app ${APP_HOME}/config/app.yml

# Fix any potential syntax errors in Gemfile
RUN sed -i 's/endgem/end\ngem/g' ${APP_HOME}/Gemfile

# Configure bundler to use ruby platform for nokogiri
RUN bundle config set force_ruby_platform true

# Create and set permissions for Yarn cache directories
RUN mkdir -p /home/app/.cache/yarn && \
    mkdir -p /tmp/.yarn-cache-999 && \
    mkdir -p /tmp/.yarn-cache && \
    chmod -R 777 /home/app/.cache/yarn && \
    chmod -R 777 /tmp/.yarn-cache-999 && \
    chmod -R 777 /tmp/.yarn-cache

# Install JavaScript dependencies as app user
WORKDIR ${APP_HOME}
USER app
ENV HOME /home/app
RUN yarn install --check-files

# Update Gemfile.lock and install gems with bundle update
RUN cd ${APP_HOME} && \
    bundle config set --local path 'vendor/bundle' && \
    rm -f Gemfile.lock && \
    bundle install
# Switch to root to create patch and modify boot.rb
USER root

# Create and copy the Ruby 3.0 logger patch file
RUN mkdir -p ${APP_HOME}/lib/patches
COPY logger_patch.rb ${APP_HOME}/lib/patches/
RUN chown app:app ${APP_HOME}/lib/patches/logger_patch.rb

# Modify boot.rb to load the logger patch early
RUN sed -i \
    '2a require "logger"\nrequire_relative "../lib/patches/logger_patch"' \
    ${APP_HOME}/config/boot.rb

# Copy entrypoint script to both required locations
COPY entrypoint.sh /usr/local/bin/
COPY entrypoint.sh /sbin/
RUN chmod 755 /usr/local/bin/entrypoint.sh /sbin/entrypoint.sh

# Create and add the que entrypoint script
COPY entrypoint-que.sh /sbin/
RUN chmod 755 /sbin/entrypoint-que.sh

# Add bash aliases
RUN echo 'alias rspec="bundle exec rspec"' >> /root/.bashrc

# Ensure tmp directory has correct permissions
RUN mkdir -p ${APP_HOME}/tmp/pids && \
    chmod -R 777 ${APP_HOME}/tmp

# Expose port
EXPOSE 8000

# Use entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
