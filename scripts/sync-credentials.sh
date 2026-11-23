#!/bin/sh
set -eu

found=0
for file in /credentials/*.sql; do
  [ -f "$file" ] || continue
  found=1
  grep -qi 'INSERT INTO certify.credential_config' "$file" || { echo "INSERT ausente: $file" >&2; exit 1; }
  grep -qi 'ON CONFLICT (credential_config_key_id) DO NOTHING' "$file" || { echo "ON CONFLICT ausente: $file" >&2; exit 1; }
  psql -X -v ON_ERROR_STOP=1 -U postgres -d postgres -f "$file"
  echo "Aplicado: $(basename "$file")"
done
[ "$found" -eq 1 ] || { echo 'Adicione um .sql em sql/credentials/ antes de executar este job.' >&2; exit 1; }