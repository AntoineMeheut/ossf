FROM php:8.5.10-apache-trixie
COPY ci/php-setup.sh /tmp/php-setup.sh
RUN sh /tmp/php-setup.sh && rm /tmp/php-setup.sh && a2enmod rewrite \
    && sed -i 's|/var/www/html|/app/web|g' /etc/apache2/sites-available/000-default.conf /etc/apache2/apache2.conf
WORKDIR /app
ENV COMPOSER_ALLOW_SUPERUSER=1
COPY composer.json composer.lock ./
RUN composer install --no-dev --prefer-dist --no-interaction --no-progress
COPY web/themes/aloha_surf/ web/themes/aloha_surf/
COPY ci/settings.php web/sites/default/settings.php
RUN mkdir -p web/sites/default/files && chown -R www-data:www-data web/sites/default/files
# Supply DATABASE_URL, DRUPAL_HASH_SALT and DRUPAL_TRUSTED_HOSTS at deployment.
EXPOSE 80
