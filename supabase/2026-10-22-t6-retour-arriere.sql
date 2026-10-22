-- =====================================================================
-- Sen Tolbi · Tâche 6 · RETOUR EN ARRIÈRE
-- Remet la base exactement comme avant : les trois règles « Accès public »
-- ouvertes à tous. À utiliser seulement si le site ne marche plus.
-- Tout est entre begin et commit : si une ligne échoue, rien n'est appliqué.
-- =====================================================================
begin;

-- 1. Retirer les nouvelles règles
drop policy if exists "utilisateurs : lire son profil (admin : tous)"         on public.utilisateurs;
drop policy if exists "utilisateurs : créer son profil vendeur ou acheteur"   on public.utilisateurs;
drop policy if exists "utilisateurs : modifier son profil (admin : tous)"     on public.utilisateurs;
drop policy if exists "utilisateurs : supprimer (admin seulement)"            on public.utilisateurs;
drop policy if exists "produits : lecture publique"                           on public.produits;
drop policy if exists "produits : un vendeur crée ses produits"               on public.produits;
drop policy if exists "produits : le propriétaire modifie (admin : tous)"     on public.produits;
drop policy if exists "produits : le propriétaire supprime (admin : tous)"    on public.produits;
drop policy if exists "commandes : acheteur, vendeur concerné ou admin"       on public.commandes;
drop policy if exists "commandes : un connecté commande à son nom"            on public.commandes;
drop policy if exists "commandes : modifier (admin seulement)"                on public.commandes;
drop policy if exists "commandes : supprimer (admin seulement)"               on public.commandes;

-- 2. Retirer les automatismes et les fonctions.
--    La vue « vendeurs_publics » est gardée exprès : elle ne montre que prénom,
--    nom et zone, et le catalogue en a besoin une fois la retouche du site publiée.
drop trigger  if exists bloquer_changement_type on public.utilisateurs;
drop trigger  if exists preparer_commande       on public.commandes;
drop function if exists public.bloquer_changement_type();
drop function if exists public.preparer_commande();
drop function if exists public.mon_type();

-- 3. Remettre les trois règles d'origine (ouvertes à tous, comme avant)
--    (Le 22/10, ces règles ont été désactivées avec « using (false) » au lieu
--     d'être supprimées : on les retire d'abord pour les recréer à l'identique.)
drop policy if exists "Accès public utilisateurs" on public.utilisateurs;
drop policy if exists "Accès public produits"     on public.produits;
drop policy if exists "Accès public commandes"    on public.commandes;
create policy "Accès public utilisateurs" on public.utilisateurs
  for all to public using (true) with check (true);
create policy "Accès public produits" on public.produits
  for all to public using (true) with check (true);
create policy "Accès public commandes" on public.commandes
  for all to public using (true) with check (true);

commit;
