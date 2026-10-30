-- =====================================================================
-- Sen Tolbi · Tâche 11 · OPTION : corrections signalées par les advisors
-- À lancer SEULEMENT si ELO est d'accord, APRÈS 2026-10-30-t11-commande-complete.sql.
-- Indépendant de la commande : le site marche avec ou sans.
-- Retour en arrière : bas de ce fichier (partie commentée).
-- Tout est entre begin et commit : si une ligne échoue, rien n'est appliqué.
-- =====================================================================
begin;

-- 1. Supprimer les trois anciennes règles « Accès public … ».
--    Depuis la T6 elles ont la condition false : elles n'autorisent plus rien,
--    elles encombrent seulement la liste des règles.
drop policy if exists "Accès public utilisateurs" on public.utilisateurs;
drop policy if exists "Accès public produits"     on public.produits;
drop policy if exists "Accès public commandes"    on public.commandes;

-- 2. Index sur les clés étrangères : accélèrent « mes commandes »,
--    « mes produits » et les vérifications des règles. Aucun effet sur les données.
create index if not exists commandes_acheteur_id_idx on public.commandes (acheteur_id);
create index if not exists commandes_vendeur_id_idx  on public.commandes (vendeur_id);
create index if not exists commandes_produit_id_idx  on public.commandes (produit_id);
create index if not exists produits_vendeur_id_idx   on public.produits  (vendeur_id);

-- 3. Fonctions « security definer » : on retire le droit de les appeler
--    directement depuis le site.
--    - mon_type() reste appelable par les connectés (les règles RLS s'en servent),
--      plus par les visiteurs (aucune règle des visiteurs ne l'utilise).
--    - Les deux fonctions de déclencheur continuent de se déclencher toutes
--      seules ; personne n'a besoin de les appeler à la main.
revoke execute on function public.mon_type()                from public, anon;
grant  execute on function public.mon_type()                to authenticated;
revoke execute on function public.preparer_commande()       from public, anon, authenticated;
revoke execute on function public.bloquer_changement_type() from public, anon, authenticated;

commit;

-- =====================================================================
-- RETOUR EN ARRIÈRE de cette option (copier à partir de « begin; » sans les --)
-- =====================================================================
-- begin;
-- create policy "Accès public utilisateurs" on public.utilisateurs for all to public using (false) with check (false);
-- create policy "Accès public produits"     on public.produits     for all to public using (false) with check (false);
-- create policy "Accès public commandes"    on public.commandes    for all to public using (false) with check (false);
-- drop index if exists public.commandes_acheteur_id_idx;
-- drop index if exists public.commandes_vendeur_id_idx;
-- drop index if exists public.commandes_produit_id_idx;
-- drop index if exists public.produits_vendeur_id_idx;
-- grant execute on function public.mon_type()                to public, anon, authenticated;
-- grant execute on function public.preparer_commande()       to public, anon, authenticated;
-- grant execute on function public.bloquer_changement_type() to public, anon, authenticated;
-- commit;
