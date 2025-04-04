# See: https://github.com/phusion/passenger-docker
FROM --platform=linux/arm64 phusion/passenger-ruby27:2.4.1
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
# Install dependencies
RUN apt-get update -qq && \
    apt-get dist-upgrade --yes && \
    apt-get install --yes pkg-config apt-utils build-essential cmake automake && \
    apt-get upgrade --fix-missing --yes --allow-remove-essential -o Dpkg::Options::="--force-confold" && \
    apt-get install --yes nodejs tzdata udev locales curl git gnupg ca-certificates \
    libpq-dev wget libxrender1 libxext6 libsodium23 libsodium-dev yarn \
    gcc make zlib1g-dev sqlite3 libgmp-dev libc6-dev \
    shared-mime-info libssl-dev libreadline-dev netcat && \
    apt-get clean && apt-get autoremove --yes && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
# Use en_CA.utf8 as our locale
RUN locale-gen en_CA.utf8
ENV LANG en_CA.utf8
ENV LANGUAGE en_CA:en
ENV LC_ALL en_CA.utf8
# Install Ruby dependencies
RUN gem install bundler -v 2.4.22
# Prepare app directory
ENV APP_HOME /home/app/workshops
RUN mkdir -p ${APP_HOME}/tmp && \
    mkdir -p ${APP_HOME}/vendor/cache && \
    chown -R app:app ${APP_HOME}
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
WORKDIR ${APP_HOME}
# Set up entrypoint scripts
COPY entrypoint.sh /sbin/entrypoint.sh
RUN chmod 755 /sbin/entrypoint.sh
COPY entrypoint-que.sh /sbin/entrypoint-que.sh
RUN chmod 755 /sbin/entrypoint-que.sh
# Add bash aliases and configure paths
RUN echo 'export PATH=$PATH:./bin:/usr/local/rvm/rubies/ruby-2.7.7/bin'>> /root/.bashrc && \
    echo 'alias rspec="bundle exec rspec"' >> /root/.bashrc

# Do NOT switch to app user, run as root (phusion requires this)
# USER app is removed

# Expose port
EXPOSE 8000

# Set entrypoint
ENTRYPOINT ["/sbin/entrypoint.sh"]