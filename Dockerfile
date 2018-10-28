FROM php:7.2-apache-stretch

# php-ext
RUN apt-get update && apt-get install -y \
    zlib1g-dev \
    libicu-dev \
    libpng-dev \
    g++
RUN set -xe \
 && docker-php-ext-configure bcmath --enable-bcmath \
 && docker-php-ext-configure intl --enable-intl \
 && docker-php-ext-install \
    bcmath \
    intl

# PGSQL
RUN apt-get update && apt-get install -y \
    libpq-dev
RUN set -xe \
    && docker-php-ext-install \
    pdo_pgsql

# Redis
RUN pecl install -o -f redis \
 && rm -rf /tmp/pear \
 && docker-php-ext-enable redis

# Node
RUN apt-get update && apt-get install -y build-essential apt-utils gnupg gcc g++ make \
 && curl -sL https://deb.nodesource.com/setup_8.x | bash - \
 && apt-get install -y nodejs

# Yarn
RUN curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
 && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
 && apt-get update && apt-get install yarn

# UTF8
RUN apt-get update && \
    apt-get install -y locales && \
    locale-gen C.UTF-8 && \
    /usr/sbin/update-locale LANG=C.UTF-8 && \
    apt-get remove -y locales
ENV LANG C.UTF-8

# Git
RUN apt-get update && apt-get install -y git

# Zip
RUN apt-get update && apt-get install -y zip unzip

# Apache SSL
RUN openssl genrsa 2048 > server.key \
 && openssl req -new -key server.key -subj "/C=JP/CN=localhost" > server.csr \
 && openssl x509 -in server.csr -days 3650 -req -signkey server.key > server.crt \
 && mkdir -p /etc/apache2/ssl \
 && cp server.crt /etc/apache2/ssl/server.crt \
 && cp server.key /etc/apache2/ssl/server.key \
 && chmod 400 /etc/apache2/ssl/server.key

# Apache FQDN
RUN echo "ServerName localhost" > /etc/apache2/conf-available/fqdn.conf \
 && a2enconf fqdn

# Apache
COPY myapp.conf /etc/apache2/sites-available/myapp.conf
RUN mkdir -p /var/www/html/public \
 && a2enmod ssl \
 && a2enmod rewrite \
 && a2enmod expires \
 && a2enmod headers \
 && a2dissite 000-default.conf \
 && a2ensite myapp.conf \
 && service apache2 restart

# Cron, Vim
RUN apt-get update && apt-get install -y cron vim

# XDebug
RUN pecl install -o -f xdebug \
 && rm -rf /tmp/pear \
 && docker-php-ext-enable xdebug
