# PINNED SEMVER TAG — verify digest during build and record in manifest.
# NOTE: wordpress:cli-* images are Alpine-based; use apk not apt-get.
FROM wordpress:cli-2.12.0-php8.3

USER root

RUN apk update && apk add --no-cache bash bash-completion nano vim

USER www-data
