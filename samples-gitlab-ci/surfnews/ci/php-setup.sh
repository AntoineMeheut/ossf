#!/bin/sh
set -eu
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl git unzip libpng-dev libonig-dev libicu-dev libpq-dev libzip-dev
docker-php-ext-install -j2 gd mbstring intl pdo_pgsql zip
curl --fail --silent --show-error --location https://getcomposer.org/download/2.11.1/composer.phar -o /usr/local/bin/composer
printf '%s  %s\n' 6f1b891e1d4927d62740276c540fb490e47689e19e102c49e8da849794882f8c /usr/local/bin/composer | sha256sum --check -
chmod 755 /usr/local/bin/composer
rm -rf /var/lib/apt/lists/*
