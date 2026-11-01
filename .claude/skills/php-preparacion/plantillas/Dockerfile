# Entorno local de pruebas generado por /preparar. No usar en producción.
FROM php:__VERSION_PHP__-apache

# Extensiones que usa el proyecto. Quita la línea si no hace falta ninguna.
RUN docker-php-ext-install __EXTENSIONES__

RUN a2enmod rewrite
COPY php.ini "$PHP_INI_DIR/conf.d/magents.ini"

# Solo si la raíz web es una subcarpeta del proyecto:
# ENV APACHE_DOCUMENT_ROOT=/var/www/html/__RAIZ_WEB__
# RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
# RUN sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf
