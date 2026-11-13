#!/bin/bash
# Lance les tests T17 sur un Postgres local (base jetable sentolbi_t17).
set -e
cd "$(dirname "$0")"
P="psql -v ON_ERROR_STOP=1 -q -X -U postgres -h localhost"
$P -c "drop database if exists sentolbi_t17" -c "create database sentolbi_t17"
D="$P -d sentolbi_t17"
$D -f 00-base-comme-supabase.sql
$D -f ../2026-10-22-t6-securite-rls.sql
$D -f ../2026-10-30-t11-commande-complete.sql
$D -f ../2026-10-30-t11-option-advisors.sql
$D -f ../2026-11-08-t17-statut-commandes.sql
$D -f 10-t17-tests-communs.sql
VARIANTE=${1:-a}
if [ "$VARIANTE" = a ]; then
  $D -f ../2026-11-08-t17-variante-a-vendeur-confirme.sql
  $D -f 20-t17-tests-variante-a.sql
else
  $D -f ../2026-11-08-t17-variante-b-equipe-confirme.sql
  $D -f 30-t17-tests-variante-b.sql
fi
$D -f ../2026-11-08-t17-retour-arriere.sql
$D -f 90-t17-tests-retour-arriere.sql
echo "Variante $VARIANTE : tous les tests sont passés."
