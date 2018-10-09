# Dockerfile
FROM php:7.1-apache

ENV PATH=$PATH:vendor/bin

RUN apt-get -q update && apt-get -q install -y --no-install-recommends \
      curl \
      git \
      python-dev \
      python-pip \
      python-setuptools \
      supervisor \
      zlib1g-dev \
 && pip install -q wheel \
 && pip install -q awscli \
 && docker-php-ext-install zip > /dev/null \
 && docker-php-ext-install pdo_mysql > /dev/null \
 && apt-get -q clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* \
 && export TERM=xterm

# Enable Apache2 rewrite (only needed by app servers)
RUN a2enmod rewrite

# Install PHP dependencies. Must copy app code before we build autoloader or run post install scripts.
# Note: Vendor files change less frequently than our application code, so we want to make vendor files cacheable.
RUN curl -sS https://getcomposer.org/installer | \
    php -- --install-dir=/usr/local/bin/ --filename=composer
COPY ./laravel/composer.json /var/www/
COPY ./laravel/composer.lock /var/www/
RUN composer install --no-scripts --no-autoloader --no-ansi --no-interaction --working-dir=/var/www/

# Copy supervisor scripts into container (only used by worker servers)
COPY ./docker/supervisord.conf /etc/supervisord.conf
COPY ./docker/entrypoint.sh /usr/bin/entrypoint.sh
RUN chmod +x /usr/bin/entrypoint.sh

# Copy application code into container
ADD ./laravel/ /var/www
ADD ./laravel/public /var/www/html
RUN chown -R www-data /var/www/bootstrap \
 && chown -R www-data /var/www/storage

# Build autoloader, run composer scripts, remove composer.
RUN composer dump-autoload --optimize --no-ansi --no-interaction --working-dir=/var/www/ \
 --no-ansi --no-interaction --working-dir=/var/www/ \
 && rm -f /usr/local/bin/composer
# && composer run-script post-install-cmd \

# Perform unit tests
# Must connect build environment to VPC and Security Group
#RUN php /var/www/vendor/bin/phpunit /var/www/tests/
