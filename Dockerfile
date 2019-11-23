FROM php:7.2-fpm

# Allow Composer to be run as root
ENV COMPOSER_ALLOW_SUPERUSER 1

# Github api token for composer
ENV API_TOKEN "5eb0d47f75160681bedf936d7010aa4cc2bfa859"
# PHP_CPPFLAGS are used by the docker-php-ext-* scripts
ENV PHP_CPPFLAGS="$PHP_CPPFLAGS -std=c++11"

#RUN apt-get update
#RUN apt-get -y install \
RUN apt-get update \
    && apt-get -y install \
            # imagick
            libmagickwand-dev \
            libmagickwand-6.q16-6 \
            # memcache
            libmemcached-dev \
            libmemcached11 \
            # for mcrypt
            libmcrypt-dev \
            libltdl7 \
            # required by composer
            git \
            zlib1g-dev \
        --no-install-recommends \
#&& echo "final"
#RUN echo "---------------" \
# PHP extension
    # build ICU 59.1 from sources (for intl ext)
    && curl -fsS -o /tmp/icu.tgz -L http://download.icu-project.org/files/icu4c/64.2/icu4c-64_2-src.tgz \
    && tar -zxf /tmp/icu.tgz -C /tmp \
    && cd /tmp/icu/source \
    && ./configure --prefix=/usr/local \
    && make \
    && make install \
    # just to be certain things are cleaned up
    && rm -rf /tmp/icu* \
#&& echo "final"
#RUN echo "---------------" \
    # Intl configure and install
    && docker-php-ext-configure intl --with-icu-dir=/usr/local \
    && docker-php-ext-install intl \
    # memcached
    && pecl install memcached && docker-php-ext-enable memcached \
    # imagick
    && pecl install imagick-3.4.4 && docker-php-ext-enable imagick \
    # xdebug
    && pecl install xdebug-2.6.0 && docker-php-ext-enable xdebug \
    # mcrypt
    && pecl install mcrypt-1.0.1 && docker-php-ext-enable mcrypt \
    # pdo opcache bcmath mcrypt bz2 pcntl
    && docker-php-ext-install -j$(nproc) pdo_mysql opcache bcmath bz2 pcntl \
    # zip (required by composer)
    && docker-php-ext-install -j$(nproc) zip \
# Cleanup to keep the images size small
    && apt-get purge -y \
        zlib1g-dev \
    && apt-get autoremove -y \
    && rm -r /var/lib/apt/lists/*

# Install composer
COPY ./install-composer.sh /install-composer

RUN chmod +x /install-composer \
    && /install-composer \
    && rm /install-composer \
    && composer global require --no-progress "hirak/prestissimo:^0.3"

RUN echo "memory_limit=-1" > "$PHP_INI_DIR/conf.d/memory-limit.ini" \
    && echo "date.timezone=${PHP_TIMEZONE:-UTC}" > "$PHP_INI_DIR/conf.d/date_timezone.ini"  \
    && echo "post_max_size=50M\nupload_max_filesize=50M" > "$PHP_INI_DIR/conf.d/upload.ini" \
    && echo "expose_php=0" > "$PHP_INI_DIR/conf.d/expose_php.ini" \
    && echo 'disable_functions="show_source, highlight_file, system, phpinfo, popen, allow_url_fopen"' \
        > "$PHP_INI_DIR/conf.d/disable_functions.ini"

WORKDIR /var/www/html
