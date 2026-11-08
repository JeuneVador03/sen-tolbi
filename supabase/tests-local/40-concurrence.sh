#!/bin/bash
# Deux annulations de la même commande à la même seconde : le stock ne doit revenir qu'une fois.
# À lancer après ./run.sh a (recrée la base sans retour en arrière).
set -e
cd "$(dirname "$0")"
P="psql -v ON_ERROR_STOP=1 -q -X -U postgres -h localhost"
$P -c "drop database if exists sentolbi_t17" -c "create database sentolbi_t17"
D="$P -d sentolbi_t17"
for f in 00-base-comme-supabase.sql ../2026-10-22-t6-securite-rls.sql ../2026-10-30-t11-commande-complete.sql \
         ../2026-10-30-t11-option-advisors.sql ../2026-11-08-t17-statut-commandes.sql 10-t17-tests-communs.sql \
         ../2026-11-08-t17-variante-a-vendeur-confirme.sql; do $D -f $f 2>/dev/null; done
ANNULE="begin; select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000c',true); set local role authenticated;
select public.changer_statut_commande('20000000-0000-0000-0000-000000000001','annulee'); select pg_sleep(2); commit;"
psql -X -U postgres -h localhost -d sentolbi_t17 -c "$ANNULE" > /tmp/t17-s1.txt 2>&1 &
sleep 0.5
psql -X -U postgres -h localhost -d sentolbi_t17 -c "$ANNULE" > /tmp/t17-s2.txt 2>&1 || true
wait
grep -h "ERROR" /tmp/t17-s1.txt /tmp/t17-s2.txt || true
STOCK=$($P -d sentolbi_t17 -At -c "select quantite from public.produits")
echo "Stock après deux annulations simultanées : $STOCK (attendu 10)"
[ "$STOCK" = 10 ]
