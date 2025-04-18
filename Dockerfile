FROM phusion/passenger-ruby27:2.4.1
ENV HOME /root
ENV RAILS_ENV development
ENV WORKSHOPS_HOME /home/app/workshops
ENV DEBIAN_FRONTEND noninteractive

# Use baseimage-docker's init process.
CMD ["/sbin/my_init"]

# prevent gpg from using IPv6 to connect to keyservers
RUN mkdir -p ~/.gnupg && \
    echo "disable-ipv6" >> ~/.gnupg/dirmngr.conf

# Add required package repositories
RUN curl -sS https://raw.githubusercontent.com/yarnpkg/releases/gh-pages/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    curl -sS https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    curl -sL https://deb.nodesource.com/setup_16.x | bash -

# Install dependencies - adding cmake for rugged gem and libssh2-1-dev
RUN apt-get update -qq && \
    apt-get dist-upgrade --yes && \
    apt-get install --yes pkg-config apt-utils build-essential cmake automake && \
    apt-get upgrade --fix-missing --yes --allow-remove-essential -o Dpkg::Options::="--force-confold" && \
    apt-get install --yes nodejs tzdata udev locales curl git gnupg ca-certificates \
    libpq-dev wget libxrender1 libxext6 libsodium23 libsodium-dev yarn \
    gcc make zlib1g-dev sqlite3 libgmp-dev libc6-dev \
    shared-mime-info libssl-dev libreadline-dev netcat libssh2-1-dev && \
    apt-get clean && apt-get autoremove --yes && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Use en_CA.utf8 as our locale
RUN locale-gen en_CA.utf8
ENV LANG en_CA.utf8
ENV LANGUAGE en_CA:en
ENV LC_ALL en_CA.utf8

# Setup global bundler config and permissions
RUN mkdir -p /usr/local/rvm/gems/ruby-2.7.7/gems && \
    mkdir -p /usr/local/rvm/gems/ruby-2.7.7@default && \
    mkdir -p /usr/local/rvm/gems/ruby-2.7.7@global && \
    chown -R app:app /usr/local/rvm/gems/ruby-2.7.7 && \
    chown -R app:app /usr/local/rvm/gems/ruby-2.7.7@default && \
    chown -R app:app /usr/local/rvm/gems/ruby-2.7.7@global && \
    chmod -R 775 /usr/local/rvm/gems/ruby-2.7.7 && \
    chmod -R 775 /usr/local/rvm/gems/ruby-2.7.7@default && \
    chmod -R 775 /usr/local/rvm/gems/ruby-2.7.7@global

# Install a specific RubyGems and bundler version
RUN bash -c "source /usr/local/rvm/scripts/rvm && \
    rvm use 2.7.7 --default && \
    rvm gemset create default && \
    rvm use 2.7.7@default --create && \
    gem update --system 3.3.26 && \
    gem install bundler -v 2.2.33"

# Prepare app directory
ENV APP_HOME /home/app/workshops
RUN mkdir -p ${APP_HOME}/tmp && \
    mkdir -p ${APP_HOME}/vendor/cache && \
    chown -R app:app ${APP_HOME} && \
    # Create yarn config directories for app user
    mkdir -p /home/app/.config && \
    mkdir -p /home/app/.cache && \
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

# Rails 6 upgrade modifications and pinning key gems to compatible versions
RUN sed -i 's/gem .rails., .~> 5.2.4.5./gem "rails", "6.0.6.1"/' ${APP_HOME}/Gemfile && \
    sed -i 's/gem .sqlite3., .~> 1.3.6./gem "sqlite3", "~> 1.4.0"/' ${APP_HOME}/Gemfile && \
    # Pin nokogiri to a version compatible with Ruby 2.7
    sed -i 's/gem .nokogiri., .~> 1.13./gem "nokogiri", "~> 1.13.10"/' ${APP_HOME}/Gemfile && \
    # Pin rails-html-sanitizer to a compatible version
    echo 'gem "rails-html-sanitizer", "~> 1.4.4"' >> ${APP_HOME}/Gemfile && \
    # Only update webpacker if it exists, don't add it if it doesn't
    sed -i 's/gem .webpacker., .~> 5.x./gem "webpacker", "~> 5.4"/' ${APP_HOME}/Gemfile || true && \
    # Temporary disable bootsnap for upgrade
    sed -i 's/require .bootsnap\/setup./#require "bootsnap\/setup"/' ${APP_HOME}/config/boot.rb

# Create bundle config for local installation
RUN mkdir -p ${APP_HOME}/.bundle && \
    echo 'BUNDLE_PATH: "vendor/bundle"' > ${APP_HOME}/.bundle/config && \
    chown -R app:app ${APP_HOME}/.bundle

# Create empty config file
RUN touch ${APP_HOME}/config/app.yml && \
    chown app:app ${APP_HOME}/config/app.yml

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

USER root

# Setup RVM-aware entrypoint
RUN bash -c 'echo "#!/bin/bash" > /sbin/entrypoint.sh && \
    echo "source /usr/local/rvm/scripts/rvm" >> /sbin/entrypoint.sh && \
    echo "cd ${APP_HOME}" >> /sbin/entrypoint.sh && \
    echo "echo \"Checking database connection...\"" >> /sbin/entrypoint.sh && \
    echo "while ! nc -z db 5432; do" >> /sbin/entrypoint.sh && \
    echo "  sleep 1" >> /sbin/entrypoint.sh && \
    echo "done" >> /sbin/entrypoint.sh && \
    echo "echo \"Connection to db 5432 port [tcp/*] succeeded!\"" >> /sbin/entrypoint.sh && \
    echo "rvm use 2.7.7 --default" >> /sbin/entrypoint.sh && \
    echo "hash -r" >> /sbin/entrypoint.sh && \
    echo "# Explicitly set PATH with RVM paths first" >> /sbin/entrypoint.sh && \
    echo "export PATH=\"/usr/local/rvm/gems/ruby-2.7.7/bin:/usr/local/rvm/gems/ruby-2.7.7@global/bin:/usr/local/rvm/rubies/ruby-2.7.7/bin:/usr/local/rvm/bin:\$PATH\"" >> /sbin/entrypoint.sh && \
    echo "# Set RVM_SILENCE_PATH_MISMATCH_CHECK_FLAG to silence RVM path warnings" >> /sbin/entrypoint.sh && \
    echo "export rvm_silence_path_mismatch_check_flag=1" >> /sbin/entrypoint.sh && \
    echo "# Run bundle check to ensure all gems are installed" >> /sbin/entrypoint.sh && \
    echo "bundle check || bundle install" >> /sbin/entrypoint.sh && \
    echo "# Start Rails server by default if no command is provided" >> /sbin/entrypoint.sh && \
    echo "if [ \"\$#\" -eq 0 ]; then" >> /sbin/entrypoint.sh && \
    echo "  echo \"Starting Rails server...\"" >> /sbin/entrypoint.sh && \
    echo "  rm -f ${APP_HOME}/tmp/pids/server.pid" >> /sbin/entrypoint.sh && \
    echo "  bundle exec rails server -b 0.0.0.0 -p 8000" >> /sbin/entrypoint.sh && \
    echo "else" >> /sbin/entrypoint.sh && \
    echo "  exec \"\$@\"" >> /sbin/entrypoint.sh && \
    echo "fi" >> /sbin/entrypoint.sh' && \
    chmod 755 /sbin/entrypoint.sh

# Add bash aliases and configure paths
RUN echo 'export PATH=$PATH:./bin:/usr/local/rvm/rubies/ruby-2.7.7/bin'>> /root/.bashrc && \
    echo 'alias rspec="bundle exec rspec"' >> /root/.bashrc

# Expose port
EXPOSE 8000

# Use entrypoint.sh
ENTRYPOINT ["/sbin/entrypoint.sh"]
