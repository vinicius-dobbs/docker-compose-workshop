#!/bin/sh
set -eu

test -s /inputs/mock-identities.sql
test -s /inputs/workshop_identity_data.csv

# A validação de correspondência é feita para cada ID inserido no seed.
ids=$(sed -n "s/^[[:space:]]*SELECT '\([0-9][0-9]*\)', jsonb_build_object(.*/\1/p" /inputs/mock-identities.sql)
test -n "$ids"
for id in $ids; do
  case "$id" in *[!0-9]*|'') echo 'ID inválido no seed' >&2; exit 1;; esac
  [ "${#id}" -eq 10 ] || { echo 'IDs devem ter 10 dígitos fictícios' >&2; exit 1; }
  grep -q "^$id," /inputs/workshop_identity_data.csv || { echo "ID $id ausente no CSV" >&2; exit 1; }
done

psql -X -v ON_ERROR_STOP=1 -U postgres -d postgres -f /inputs/mock-identities.sql
echo 'Identidades fictícias sincronizadas. Recrie somente o Certify após alterar o CSV.'