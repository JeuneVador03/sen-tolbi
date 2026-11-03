-- =====================================================================
-- Sen Tolbi · Tâche 14 · Étape 2 : suppression des données de test
-- NE PAS LANCER avant l'accord d'ELO et de Coumba.
-- Tout se passe en UNE transaction : si une ligne échoue, rien n'est fait.
-- À coller en entier dans Supabase > SQL Editor > New query, puis « Run ».
--
-- On garde : comptes +vendeur et +acheteur, produits Maad et Fraises,
--            comptes de Coumba (icloud, cthiam@, coumba.thiam148@),
--            compte de connexion mouhamadoulo1409@gmail.com.
-- On supprime : 8 commandes, 2 produits, 7 profils, 3 anciennes règles.
--
-- Résultat attendu (dernier tableau) :
--   profils 12 → 5 · produits 4 → 2 · commandes 8 → 0
--   comptes de connexion : 9 → 9 ici, puis 6 après l'étape 3 (tableau de bord)
--
-- Retour en arrière : 2026-11-03-t14-retour-arriere.sql (relit la sauvegarde).
-- =====================================================================

begin;

-- 0. Comptage AVANT (gardé dans une table temporaire pour l'afficher à la fin)
create temp table t14_comptage on commit drop as
select 'avant' as moment,
       (select count(*) from public.utilisateurs) as profils,
       (select count(*) from public.produits)     as produits,
       (select count(*) from public.commandes)    as commandes,
       (select count(*) from auth.users)          as comptes_connexion;

-- 1. Sauvegarde des lignes supprimées dans un schéma à part
--    (personne d'autre que le propriétaire de la base ne peut le lire)
create schema if not exists sauvegarde_t14;
revoke all on schema sauvegarde_t14 from public, anon, authenticated;

create table sauvegarde_t14.commandes as
select * from public.commandes
where id in (
  'b83f1e58-6688-4f51-81ea-0075a5a00a27',  -- 14/07, Fraises, compte « Vgv Fff »
  '99203d3c-f62d-4736-8453-eca61c0685c7',  -- 21/10 21:49, STL-383970
  'aa1f6948-9b68-492a-9d74-610353fe6631',  -- 26/10 08:18
  'e229a120-0ab3-4158-9ad6-6c472713c309',  -- 30/10, +test8
  'd25e4d5f-0f53-4ef0-b7b1-72df7194a1f7',  -- 30/10, +test8
  '952e4a1a-85e4-4829-b935-5d13694f51d5',  -- 30/10, +test8
  '291a2508-1db4-45d3-88b0-8de504da82ad',  -- 30/10, +test8
  'd0d84e1a-167f-403b-826d-9e9f8237b065'   -- 30/10, +test8
);

create table sauvegarde_t14.produits as
select * from public.produits
where id in (
  '6eab8747-dd18-4f93-b864-37f486bfd4e5',  -- TEST TOMATES
  'b325d7e0-b2a1-4a8c-8597-4c06a8c3c968'   -- TEST T11
);

create table sauvegarde_t14.utilisateurs as
select * from public.utilisateurs
where id in (
  '67a2e08a-bd53-463e-8d01-bcdfefd350b5',  -- +test6
  '217395e7-f591-499a-8932-8b278233443e',  -- +test7
  'bf48c4a1-edcf-4617-a326-72d34fdc9f3c',  -- +test8
  'a592bfcb-86a1-4b9b-a566-3cb62b32e6d9',  -- Jhbbb V bb (sans compte de connexion)
  'f582891d-ca29-4ba1-91b8-9b789c8f4d76',  -- Coumba Thiam acheteur (sans compte de connexion)
  'e1751611-e5e7-4a15-96af-9bb975167580',  -- Ffff Ccff (sans compte de connexion)
  '4398d368-0b3a-45c2-9c7f-08acf224c936'   -- Rdd Bbb (sans compte de connexion)
);

-- 2. Suppression dans le bon ordre : commandes → produits → profils
--    (une commande pointe vers un produit et deux profils)
delete from public.commandes    where id in (select id from sauvegarde_t14.commandes);
delete from public.produits     where id in (select id from sauvegarde_t14.produits);
delete from public.utilisateurs where id in (select id from sauvegarde_t14.utilisateurs);

-- 3. Les 3 anciennes règles « Accès public … » (condition false, sans effet)
drop policy if exists "Accès public utilisateurs" on public.utilisateurs;
drop policy if exists "Accès public produits"     on public.produits;
drop policy if exists "Accès public commandes"    on public.commandes;

-- 4. Sécurité : si les nombres ne sont pas ceux attendus, tout est annulé
do $$
begin
  if (select count(*) from sauvegarde_t14.commandes)    <> 8
  or (select count(*) from sauvegarde_t14.produits)     <> 2
  or (select count(*) from sauvegarde_t14.utilisateurs) <> 7 then
    raise exception 'Nombre de lignes inattendu : rien n''est supprimé.';
  end if;
end $$;

-- 5. Comptage APRÈS, affiché à côté du comptage AVANT
insert into t14_comptage
select 'après',
       (select count(*) from public.utilisateurs),
       (select count(*) from public.produits),
       (select count(*) from public.commandes),
       (select count(*) from auth.users);

select * from t14_comptage order by moment desc;

commit;

-- =====================================================================
-- Étape 3 (après ce SQL) : supprimer les 3 comptes de connexion de test
-- dans Supabase > Authentication > Users :
--   coumba.thiam148+test6@gmail.com
--   coumba.thiam148+test7@gmail.com
--   coumba.thiam148+test8@gmail.com
-- Pour chacun : les « … » au bout de la ligne > Delete user > confirmer.
-- Cette étape n'a pas de retour en arrière : pour revenir, il faudrait
-- recréer le compte par la page d'inscription.
-- =====================================================================
