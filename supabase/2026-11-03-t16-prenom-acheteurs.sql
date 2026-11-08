-- =====================================================================
-- Sen Tolbi · Tâche 16 · Prénom de l'acheteur dans l'espace vendeur
-- (question 1 de Coumba, 03/11/2026)
--
-- Problème : la règle « utilisateurs : lire son profil » ne laisse lire
-- que son propre profil. Le vendeur ne peut donc pas lire le prénom des
-- acheteurs qui lui ont commandé.
--
-- Solution : une fonction prenoms_de_mes_acheteurs() qui renvoie
-- UNIQUEMENT l'id et le prénom des acheteurs ayant passé au moins une
-- commande AU VENDEUR CONNECTÉ. Rien d'autre (pas de nom, téléphone,
-- e-mail, zone). Un non-connecté ne peut pas l'appeler.
--
-- Côté site (Coumba, dashboard-agriculteur.html) :
--   const { data } = await window._sb.rpc('prenoms_de_mes_acheteurs');
--   // data = [{ acheteur_id: '…', prenom: '…' }, …]
--
-- ÉTAPE 1 (lecture seule, ne change rien) : la requête juste en dessous
-- montre ce que chaque vendeur verra.
-- ÉTAPE 2 : le bloc begin … commit crée la fonction.
-- Retour en arrière : 2026-11-03-t16-retour-arriere.sql
-- =====================================================================

-- ---------- ÉTAPE 1 : lecture seule ----------
-- select v.email as vendeur,
--        count(distinct c.acheteur_id) as nb_acheteurs,
--        string_agg(distinct coalesce(u.prenom, '(sans profil)'), ', ') as prenoms_visibles
-- from public.commandes c
-- join auth.users v on v.id = c.vendeur_id
-- left join public.utilisateurs u on u.id = c.acheteur_id
-- group by v.email;

-- ---------- ÉTAPE 2 : création ----------
begin;

create or replace function public.prenoms_de_mes_acheteurs()
returns table (acheteur_id uuid, prenom text)
language sql
stable
security definer
set search_path = ''
as $$
  select distinct u.id, u.prenom
  from public.utilisateurs u
  join public.commandes c on c.acheteur_id = u.id
  where c.vendeur_id = (select auth.uid());
$$;

-- Seuls les comptes connectés peuvent l'appeler (et ne voient que leurs acheteurs).
revoke execute on function public.prenoms_de_mes_acheteurs() from public;
revoke execute on function public.prenoms_de_mes_acheteurs() from anon;
grant execute on function public.prenoms_de_mes_acheteurs() to authenticated;

commit;

-- Vérification (lecture seule) : doit renvoyer une ligne, security definer = true.
-- select proname, prosecdef from pg_proc where proname = 'prenoms_de_mes_acheteurs';
