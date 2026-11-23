#!/bin/sh
set -eu

# Usar as CAs padrão da JVM e importar apenas certificados públicos locais.
for ca in /home/inji/workshop-ca/*.der /home/inji/workshop-ca/*.crt /home/inji/workshop-ca/*.pem; do
  [ -f "$ca" ] || continue
  [ -s "$ca" ] || { echo "CA vazia: $ca" >&2; exit 1; }
  alias_name="workshop-$(basename "$ca" | tr -c '[:alnum:]' '-')"
  keytool -importcert -noprompt -trustcacerts \
    -alias "$alias_name" -file "$ca" \
    -keystore /opt/java/openjdk/lib/security/cacerts -storepass changeit >/dev/null 2>&1 || \
    keytool -list -keystore /opt/java/openjdk/lib/security/cacerts \
      -storepass changeit -alias "$alias_name" >/dev/null 2>&1
done

did_cert=/home/inji/workshop-did-tls/certify-nginx.crt
[ -s "$did_cert" ] || { echo 'Certificado TLS do DID local ausente; inicie certify-nginx antes do Verify.' >&2; exit 1; }
keytool -importcert -noprompt -trustcacerts \
  -alias workshop-certify-nginx-did -file "$did_cert" \
  -keystore /opt/java/openjdk/lib/security/cacerts -storepass changeit >/dev/null 2>&1 || \
  keytool -list -keystore /opt/java/openjdk/lib/security/cacerts \
    -storepass changeit -alias workshop-certify-nginx-did >/dev/null 2>&1

exec java -jar \
  "-Dspring.cloud.config.label=${spring_config_label_env:-}" \
  "-Dspring.profiles.active=${active_profile_env:-}" \
  "-Dspring.cloud.config.uri=${spring_config_url_env:-}" \
  verify-service.jar