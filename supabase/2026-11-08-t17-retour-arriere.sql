-- =====================================================================
-- Sen Tolbi · Tâche 17 · RETOUR EN ARRIÈRE (variante A ou B)
-- Remet la base comme avant la T17. À coller en entier dans
-- Supabase > SQL Editor, puis Run.
--
-- Ce qui n'est PAS défait : les statuts déjà changés restent dans les
-- commandes, et le stock déjà remis par des annulations reste remis
-- (c'est la vraie quantité disponible). Les commandes gardent leur statut
-- (confirmee, livree, annulee) : le site affichera ces mots tels quels.
--
-- Variante B uniquement : s'il existe un compte admin, la ligne 3 échoue
-- volontairement (la base refuserait ce compte). Le repasser d'abord en
-- vendeur ou acheteur :
--   update public.utilisateurs set type = 'acheteur' where type = 'admin';
-- =====================================================================
begin;

-- 1. Garde et fonction.
drop trigger  if exists proteger_statut_commande on public.commandes;
drop function if exists public.proteger_statut_commande();
drop function if exists public.changer_statut_commande(uuid, text);

-- 2. Table des droits.
drop table if exists public.droits_statut_commande;

-- 3. Type « admin » de nouveau refusé (comme avant la variante B ;
--    sans effet si c'était la variante A).
alter table public.utilisateurs drop constraint if exists utilisateurs_type_check;
alter table public.utilisateurs
  add constraint utilisateurs_type_check
  check (type in ('vendeur', 'acheteur'));

-- 4. Statut redevient un texte libre, comme avant.
alter table public.commandes drop constraint if exists commandes_statut_check;
alter table public.commandes alter column statut drop not null;

commit;
