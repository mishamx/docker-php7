FROM php:7.1-fpm

# Allow Composer to be run as root
ENV COMPOSER_ALLOW_SUPERUSER 1

# Github api token for composer
ENV API_TOKEN "e182383413576177cb2ae1cb4f626889a562ea07"
# PHP_CPPFLAGS are used by the docker-php-ext-* scripts
ENV PHP_CPPFLAGS="$PHP_CPPFLAGS -std=c++11"

RUN apt-get update \
    && apt-get -y install \

            # imagick
            libmagickwand-dev \
            libmagickwand-6.q16-2 \

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

# PHP extension

    # build ICU 59.1 from sources (for intl ext)
    && curl -fsS -o /tmp/icu.tgz -L http://download.icu-project.org/files/icu4c/59.1/icu4c-59_1-src.tgz \
    && tar -zxf /tmp/icu.tgz -C /tmp \
    && cd /tmp/icu/source \
    && ./configure --prefix=/usr/local \
    && make \
    && make install \
    # just to be certain things are cleaned up
    && rm -rf /tmp/icu* \

    # Intl configure and install
    && docker-php-ext-configure intl --with-icu-dir=/usr/local \
    && docker-php-ext-install intl \

    # memcached
    && pecl install memcached && docker-php-ext-enable memcached \

    # imagick
    && pecl install imagick-3.4.3 && docker-php-ext-enable imagick \

    # xdebug
    && pecl install xdebug-2.5.0 && docker-php-ext-enable xdebug \

    # pdo opcache bcmath mcrypt bz2 pcntl
    && docker-php-ext-install -j$(nproc) pdo_mysql opcache bcmath mcrypt bz2 pcntl \

    # zip (required by composer)
    && docker-php-ext-install -j$(nproc) zip \

# Cleanup to keep the images size small
    && apt-get purge -y \
        zlib1g-dev \
    && apt-get autoremove -y \
    && rm -r /var/lib/apt/lists/* \

# Create base directory
    && mkdir -p /var/www/html

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
