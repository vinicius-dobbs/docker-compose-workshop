#!/bin/sh
set -eu
if [ ! -s /workshop/oidckeystore.p12 ]; then
  unzip -p /assets/oidckeystore.p12.zip oidckeystore.p12 > /workshop/oidckeystore.p12
fi
openssl pkcs12 -legacy -in /workshop/oidckeystore.p12 -clcerts -nokeys \
  -passin "pass:${WORKSHOP_KEYSTORE_PASSWORD}" | openssl x509 -pubkey -noout \
  > /workshop/client-public.pem
test -s /workshop/client-public.pem
echo "Chave pública do cliente mock preparada."