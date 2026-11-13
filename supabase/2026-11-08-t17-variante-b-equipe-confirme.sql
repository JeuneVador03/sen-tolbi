-- =====================================================================
-- Sen Tolbi · Tâche 17 · ÉTAPE 2, VARIANTE B : « l'équipe confirme »
-- (L'équipe Sen Tolbi confirme et marque « livrée » depuis l'espace admin ;
--  D2 : l'acheteur ou le vendeur annule tant que c'est en attente,
--  l'équipe peut aussi annuler après confirmation.)
--
-- NE PAS APPLIQUER avant la décision de la réunion du 8/11 (D1, D2, D3).
-- À lancer APRÈS 2026-11-08-t17-statut-commandes.sql.
-- Ne pas lancer aussi la variante A : c'est l'une OU l'autre.
--
-- À coller en entier dans Supabase > SQL Editor, puis Run.
-- =====================================================================
begin;

-- ---------------------------------------------------------------------
-- 1. La base accepte enfin le type « admin ».
--    Aujourd'hui la contrainte n'accepte que vendeur et acheteur (d'où
--    « aucun admin possible »). Ce qui reste protégé (T6) :
--      - l'inscription ne peut créer que vendeur ou acheteur ;
--      - personne ne peut changer son propre type depuis le site ;
--    donc seul l'éditeur SQL peut nommer un admin (point 3).
-- ---------------------------------------------------------------------
alter table public.utilisateurs drop constraint utilisateurs_type_check;
alter table public.utilisateurs
  add constraint utilisateurs_type_check
  check (type in ('vendeur', 'acheteur', 'admin'));

-- ---------------------------------------------------------------------
-- 2. Les droits.
-- ---------------------------------------------------------------------
insert into public.droits_statut_commande (role, statut_avant, statut_apres) values
  -- L'équipe confirme, marque livrée, et peut annuler à tout moment avant
  -- la livraison.
  ('admin',    'en_attente', 'confirmee'),
  ('admin',    'confirmee',  'livree'),
  ('admin',    'en_attente', 'annulee'),
  ('admin',    'confirmee',  'annulee'),
  -- Le vendeur et l'acheteur peuvent annuler tant que c'est en attente.
  ('vendeur',  'en_attente', 'annulee'),
  ('acheteur', 'en_attente', 'annulee');

-- Variante « mixte » (proposition du document de réunion : le vendeur
-- confirme, l'équipe marque livrée) : enlever les deux -- de la ligne
-- ci-dessous avant de lancer le fichier.
-- insert into public.droits_statut_commande values ('vendeur', 'en_attente', 'confirmee');

commit;

-- ---------------------------------------------------------------------
-- 3. Nommer un admin (D3) : PAS fait ici, à lancer à part une fois la
--    personne choisie. Remplacer l'adresse, enlever les --, puis Run.
--    Attention : un compte admin n'est plus acheteur ni vendeur ; utiliser
--    un compte réservé à l'équipe, avec un mot de passe solide.
-- ---------------------------------------------------------------------
-- update public.utilisateurs set type = 'admin'
--  where id = (select id from auth.users where email = 'adresse@exemple.com');
