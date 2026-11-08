#!/bin/bash
# Tests T19 sur un Postgres local (base jetable sentolbi_t19), jamais la base réelle.
set -e
cd "$(dirname "$0")"
P="psql -v ON_ERROR_STOP=1 -q -X -U postgres -h localhost"
$P -c "drop database if exists sentolbi_t19" -c "create database sentolbi_t19"
D="$P -d sentolbi_t19"
$D -f 00-base-comme-supabase.sql
$D -f ../2026-10-22-t6-securite-rls.sql
$D -f ../2026-10-30-t11-commande-complete.sql
$D -f ../2026-10-30-t11-option-advisors.sql
$D -f 10-donnees-avant.sql
PGOPTIONS="-c timezone=Europe/Paris" $D -f ../2026-11-08-t19-heures-avec-fuseau.sql
$D -f 20-tests-apres.sql
PGOPTIONS="-c timezone=Europe/Paris" $D -f ../2026-11-08-t19-retour-arriere.sql
$D -f 30-tests-retour-arriere.sql
echo "T19 : tous les tests sont passés."
