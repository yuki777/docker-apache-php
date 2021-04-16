FROM php:7.4-apache-buster

#######################################################
# UTF8
#######################################################
RUN apt-get update && \
    apt-get install -y locales && \
    locale-gen C.UTF-8 && \
    /usr/sbin/update-locale LANG=C.UTF-8 && \
    apt-get remove -y locales
ENV LANG C.UTF-8

#######################################################
# User
#######################################################
RUN useradd -ms /bin/bash docker && adduser docker sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

#######################################################
# Dev tools
#######################################################
# Git Zip Cron Vim
RUN apt-get update && apt-get install -y git zip unzip cron vim

#######################################################
# .bashrc
#######################################################
USER docker
RUN echo 'eval "$(symfony-autocomplete)"' > ~/.bash_profile
RUN { \
        echo "alias ls='ls --color=auto'"; \
        echo "alias ll='ls --color=auto -alF'"; \
        echo "alias la='ls --color=auto -A'"; \
        echo "alias l='ls --color=auto -CF'"; \
    } >> ~/.bashrc
USER root

#######################################################
# Apache
#######################################################
RUN chown docker:docker /var/www/html
RUN echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf \
 && a2enconf servername
CMD ["apache2-foreground"]
# Apache user
ENV APACHE_RUN_USER=docker \
    APACHE_RUN_GROUP=docker
# Apache SSL
RUN openssl genrsa 2048 > server.key \
 && openssl req -new -key server.key -subj "/C=JP/CN=localhost" > server.csr \
 && openssl x509 -in server.csr -days 3650 -req -signkey server.key > server.crt \
 && mkdir -p /etc/apache2/ssl \
 && cp server.crt /etc/apache2/ssl/server.crt \
 && cp server.key /etc/apache2/ssl/server.key \
 && chmod 400 /etc/apache2/ssl/server.key
# myapp.conf
COPY myapp.conf /etc/apache2/sites-available/myapp.conf
RUN mkdir -p /var/www/html/public \
 && a2enmod ssl \
 && a2enmod rewrite \
 && a2enmod expires \
 && a2enmod headers \
 && a2dissite 000-default.conf \
 && a2ensite myapp.conf \
 && service apache2 restart

#######################################################
# PHP
#######################################################
# Main PHP extensions
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
# GD, Exif
RUN apt-get update \
 && apt-get install -y libjpeg-dev libfreetype6-dev \
 && docker-php-ext-configure gd \
 && docker-php-ext-install -j$(nproc) gd exif
# MySQL
RUN docker-php-ext-install pdo_mysql

#######################################################
# Node, Yarn
#######################################################
# Node
RUN apt-get update && apt-get install -y build-essential apt-utils gnupg gcc g++ make \
 && curl -sL https://deb.nodesource.com/setup_12.x | bash - \
 && apt-get install -y nodejs
# Yarn
RUN curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
 && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
 && apt-get update && apt-get install yarn

# php-mongodb
RUN apt-get install -y libcurl4-openssl-dev pkg-config libssl-dev \
 && pecl install -o -f mongodb \
 && rm -rf /tmp/pear \
 && docker-php-ext-enable mongodb

# php-memcached
RUN apt-get install -y libmemcached-dev \
 && yes '' | pecl install -o -f memcached \
 && rm -rf /tmp/pear \
 && docker-php-ext-enable memcached

#######################################################
# Dockerize
#######################################################
ENV DOCKERIZE_VERSION v0.6.1
RUN apt-get update && apt-get install -y wget \
 && wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
 && tar -C /usr/local/bin -xzvf dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
 && rm dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz

# opcache
RUN docker-php-ext-install opcache
COPY opcache.ini /usr/local/etc/php/conf.d/opcache.ini

# composer
RUN wget https://getcomposer.org/composer-stable.phar \
 && mv composer-stable.phar /usr/local/bin/composer \
 && chmod 755 /usr/local/bin/composer

# imagick
RUN apt-get update \
 && apt-get install -y libmagickwand-dev --no-install-recommends \
 && pecl install -o -f imagick\
 && rm -rf /tmp/pear \
 && docker-php-ext-enable imagick

# ext-zip
RUN apt-get update && \
    apt-get install -y libzip-dev && \
    docker-php-ext-install zip

# xdebug
RUN pecl install xdebug

# sockets
RUN docker-php-ext-install sockets

# ext-grpc
RUN apt-get update && \
    apt-get -y --no-install-recommends install g++ zlib1g-dev && \
    pecl install grpc && \
    docker-php-ext-enable grpc
