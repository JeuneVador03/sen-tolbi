-- =====================================================================
-- Sen Tolbi · Tâche 14 · Retour en arrière de la suppression
-- À utiliser seulement si on veut remettre les données supprimées.
-- Remet profils, produits, commandes et les 3 anciennes règles à l'identique.
-- Les comptes de connexion supprimés à l'étape 3 ne reviennent pas.
-- =====================================================================

begin;

-- Ordre inverse : profils → produits → commandes
insert into public.utilisateurs select * from sauvegarde_t14.utilisateurs;
insert into public.produits     select * from sauvegarde_t14.produits;

-- Le déclencheur preparer_commande recalcule les montants et baisse le stock
-- à chaque nouvelle commande : on le coupe le temps de remettre les anciennes.
alter table public.commandes disable trigger preparer_commande;
insert into public.commandes select * from sauvegarde_t14.commandes;
alter table public.commandes enable trigger preparer_commande;

-- Les 3 anciennes règles, désactivées comme avant (condition false)
create policy "Accès public utilisateurs" on public.utilisateurs for all using (false) with check (false);
create policy "Accès public produits"     on public.produits     for all using (false) with check (false);
create policy "Accès public commandes"    on public.commandes    for all using (false) with check (false);

select (select count(*) from public.utilisateurs) as profils,
       (select count(*) from public.produits)     as produits,
       (select count(*) from public.commandes)    as commandes;

commit;

-- Quand tout est validé et qu'on n'a plus besoin de revenir en arrière :
--   drop schema sauvegarde_t14 cascade;
