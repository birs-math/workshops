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

# Rails 6 upgrade modifications and pinning key gems to compatible versions
RUN sed -i 's/gem .rails., .~> 5.2.4.5./gem "rails", "6.0.6.1"/' ${APP_HOME}/Gemfile && \
    sed -i 's/gem .sqlite3., .~> 1.3.6./gem "sqlite3", "~> 1.4.0"/' ${APP_HOME}/Gemfile && \
    sed -i 's/gem .nokogiri., .~> 1.13./gem "nokogiri", force_ruby_platform: true/' ${APP_HOME}/Gemfile && \
    echo 'gem "rails-html-sanitizer", "~> 1.4.4"' >> ${APP_HOME}/Gemfile && \
    echo 'gem "rubyzip", "~> 2.3.0"' >> ${APP_HOME}/Gemfile && \
    sed -i 's/gem .webpacker., .~> 5.x./gem "webpacker", "~> 5.4"/' ${APP_HOME}/Gemfile || true && \
    sed -i 's/require .bootsnap\/setup./#require "bootsnap\/setup"/' ${APP_HOME}/config/boot.rb

# Create empty config file
RUN touch ${APP_HOME}/config/app.yml && \
    chown app:app ${APP_HOME}/config/app.yml

# Fix any potential syntax errors in Gemfile
RUN sed -i 's/endgem/end\ngem/g' ${APP_HOME}/Gemfile

# Configure bundler to use ruby platform for nokogiri
RUN bundle config set force_ruby_platform true

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

# Create the Ruby 3.0 logger patch
RUN mkdir -p ${APP_HOME}/lib/patches
RUN echo '# lib/patches/logger_patch.rb' > ${APP_HOME}/lib/patches/logger_patch.rb && \
    echo 'require "logger"' >> ${APP_HOME}/lib/patches/logger_patch.rb && \
    echo '' >> ${APP_HOME}/lib/patches/logger_patch.rb && \
    echo '# Add this before Rails loads' >> ${APP_HOME}/lib/patches/logger_patch.rb && \
    echo 'module ActiveSupport' >> ${APP_HOME}/lib/patches/logger_patch.rb && \
    echo '  module LoggerThreadSafeLevel' >> ${APP_HOME}/lib/patches/logger_patch.rb && \
    echo '    # Explicitly define Logger' >> ${APP_HOME}/lib/patches/logger_patch.rb && \
    echo '    Logger = ::Logger unless defined?(Logger)' >> ${APP_HOME}/lib/patches/logger_patch.rb && \
    echo '  end' >> ${APP_HOME}/lib/patches/logger_patch.rb && \
    echo 'end' >> ${APP_HOME}/lib/patches/logger_patch.rb && \
    chown app:app ${APP_HOME}/lib/patches/logger_patch.rb

# Modify boot.rb to load the logger patch early
RUN sed -i '2a require "logger"\nrequire_relative "../lib/patches/logger_patch"' ${APP_HOME}/config/boot.rb

# Setup entrypoint with Rails compatibility fix
RUN echo '#!/bin/bash' > /usr/local/bin/entrypoint.sh && \
    echo 'cd ${APP_HOME}' >> /usr/local/bin/entrypoint.sh && \
    echo 'echo "Checking database connection..."' >> /usr/local/bin/entrypoint.sh && \
    echo 'while ! nc -z db 5432; do' >> /usr/local/bin/entrypoint.sh && \
    echo '  sleep 1' >> /usr/local/bin/entrypoint.sh && \
    echo 'done' >> /usr/local/bin/entrypoint.sh && \
    echo 'echo "Connection to db 5432 port [tcp/*] succeeded!"' >> /usr/local/bin/entrypoint.sh && \
    echo 'bundle check || bundle install' >> /usr/local/bin/entrypoint.sh && \
    echo '' >> /usr/local/bin/entrypoint.sh && \
    echo '# Fix Rails 6 compatibility with Ruby 3' >> /usr/local/bin/entrypoint.sh && \
    echo 'LOGGER_FILE=$(find vendor/bundle -path "*/active_support/logger_thread_safe_level.rb")' >> /usr/local/bin/entrypoint.sh && \
    echo 'if [ -f "$LOGGER_FILE" ]; then' >> /usr/local/bin/entrypoint.sh && \
    echo '  echo "Patching Rails logger file for Ruby 3 compatibility"' >> /usr/local/bin/entrypoint.sh && \
    echo '  grep -q "require \"logger\"" "$LOGGER_FILE" || sed -i '"'"'1i require "logger"'"'"' "$LOGGER_FILE"' >> /usr/local/bin/entrypoint.sh && \
    echo '  grep -q "Logger = ::Logger" "$LOGGER_FILE" || sed -i '"'"'s/module LoggerThreadSafeLevel/module LoggerThreadSafeLevel\\n    Logger = ::Logger unless defined?(Logger)/g'"'"' "$LOGGER_FILE"' >> /usr/local/bin/entrypoint.sh && \
    echo 'fi' >> /usr/local/bin/entrypoint.sh && \
    echo '' >> /usr/local/bin/entrypoint.sh && \
    echo 'if [ "$#" -eq 0 ]; then' >> /usr/local/bin/entrypoint.sh && \
    echo '  echo "Starting Rails server..."' >> /usr/local/bin/entrypoint.sh && \
    echo '  rm -f ${APP_HOME}/tmp/pids/server.pid' >> /usr/local/bin/entrypoint.sh && \
    echo '  bundle exec rails server -b 0.0.0.0 -p 8000' >> /usr/local/bin/entrypoint.sh && \
    echo 'else' >> /usr/local/bin/entrypoint.sh && \
    echo '  exec "$@"' >> /usr/local/bin/entrypoint.sh && \
    echo 'fi' >> /usr/local/bin/entrypoint.sh && \
    chmod 755 /usr/local/bin/entrypoint.sh

# Add bash aliases
RUN echo 'alias rspec="bundle exec rspec"' >> /root/.bashrc

# Expose port
EXPOSE 8000

# Use entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]