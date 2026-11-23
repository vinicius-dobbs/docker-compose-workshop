#!/bin/sh
set -eu

# CA local opcional: importar somente certificados públicos informados pelo operador.
# Sem arquivos no diretório, usar as CAs padrão da JVM (TLS continua verificado).
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

exec ./configure_start.sh java -jar \
  "-Dloader.path=${loader_path_env:-}" \
  "-Dspring.cloud.config.label=${spring_config_label_env:-}" \
  "-Dspring.profiles.active=${active_profile_env:-}" \
  "-Dspring.cloud.config.uri=${spring_config_url_env:-}" \
  certify-service.jar