-- =====================================================================
-- Sen Tolbi · Tâche 17 · ÉTAPE 2, VARIANTE A : « le vendeur confirme »
-- (D1 option A : le vendeur fait tout ; D2 option A : annulation possible
--  par l'acheteur ou le vendeur tant que la commande est en attente.)
--
-- NE PAS APPLIQUER avant la décision de la réunion du 8/11.
-- À lancer APRÈS 2026-11-08-t17-statut-commandes.sql.
-- Ne pas lancer aussi la variante B : c'est l'une OU l'autre.
-- Pour passer plus tard à la variante B : lancer
--   delete from public.droits_statut_commande;
-- puis le fichier de la variante B.
--
-- À coller en entier dans Supabase > SQL Editor, puis Run.
-- =====================================================================
begin;

insert into public.droits_statut_commande (role, statut_avant, statut_apres) values
  -- Le vendeur accepte la commande, puis la marque livrée.
  ('vendeur',  'en_attente', 'confirmee'),
  ('vendeur',  'confirmee',  'livree'),
  -- Le vendeur peut refuser (annuler) une commande pas encore confirmée.
  ('vendeur',  'en_attente', 'annulee'),
  -- L'acheteur peut annuler tant que le vendeur n'a pas confirmé.
  ('acheteur', 'en_attente', 'annulee');

-- Après confirmation, personne ne peut annuler depuis le site dans cette
-- variante (il n'existe aucun admin). Si l'équipe doit annuler une commande
-- confirmée, c'est à la main dans l'éditeur SQL, et le stock est remis à la
-- main aussi (voir le compte rendu T17).

commit;
