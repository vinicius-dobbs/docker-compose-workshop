#!/bin/sh
set -eu

cert=/etc/nginx/workshop-tls/certify-nginx.crt
key=/etc/nginx/workshop-tls/certify-nginx.key

if [ ! -s "$cert" ] || [ ! -s "$key" ]; then
  openssl req -x509 -newkey rsa:2048 -sha256 -nodes \
    -keyout "$key" -out "$cert" -days 365 \
    -subj '/CN=certify-nginx' \
    -addext 'subjectAltName=DNS:certify-nginx' >/dev/null 2>&1
  chmod 600 "$key"
fi

exec /docker-entrypoint.sh nginx -g 'daemon off;'