#!/bin/sh
set -eu

until pg_isready -h db -p 5432 -U postgres -d postgres >/dev/null 2>&1; do
  echo "Aguardando o PostgreSQL do Supabase..."
  sleep 2
done

psql -h db -U postgres -d postgres <<'SQL'
CREATE TABLE IF NOT EXISTS public.wacrm_schema_migrations (
  name text PRIMARY KEY,
  applied_at timestamptz NOT NULL DEFAULT now()
);
SQL

for migration in /migrations/*.sql; do
  name="$(basename "$migration")"
  if psql -h db -U postgres -d postgres -tAc \
    "SELECT 1 FROM public.wacrm_schema_migrations WHERE name = '$name'" | grep -q 1; then
    echo "Migração já aplicada: $name"
    continue
  fi

  echo "Aplicando: $name"
  psql -v ON_ERROR_STOP=1 -h db -U postgres -d postgres -f "$migration"
  psql -v ON_ERROR_STOP=1 -h db -U postgres -d postgres \
    -c "INSERT INTO public.wacrm_schema_migrations (name) VALUES ('$name') ON CONFLICT (name) DO NOTHING"
done
