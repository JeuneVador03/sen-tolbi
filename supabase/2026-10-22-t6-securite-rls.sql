-- =====================================================================
-- Sen Tolbi · Tâche 6 · Sécurité des données (RLS)
-- À coller en entier dans Supabase > SQL Editor, puis Run.
-- Tout est entre begin et commit : si une ligne échoue, rien n'est appliqué.
-- =====================================================================
begin;

-- ---------------------------------------------------------------------
-- 1. Fonction « mon_type » : renvoie le type (vendeur, acheteur, admin)
--    de la personne connectée.
--    Elle évite la boucle : une règle sur « utilisateurs » qui relirait
--    « utilisateurs » pour savoir si on est admin se rappellerait sans fin.
--    SECURITY DEFINER = la fonction lit la table avec les droits de son
--    propriétaire, donc sans repasser par les règles RLS.
-- ---------------------------------------------------------------------
create or replace function public.mon_type()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select type from public.utilisateurs where id = (select auth.uid());
$$;

-- ---------------------------------------------------------------------
-- 2. On supprime les trois règles « Accès public » (ouvertes à tous)
--    et on s'assure que RLS reste activé.
-- ---------------------------------------------------------------------
drop policy if exists "Accès public utilisateurs" on public.utilisateurs;
drop policy if exists "Accès public produits"     on public.produits;
drop policy if exists "Accès public commandes"    on public.commandes;

-- (Si ce script a déjà été lancé une fois, on retire aussi ses propres règles
--  pour pouvoir le relancer sans erreur.)
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

alter table public.utilisateurs enable row level security;
alter table public.produits     enable row level security;
alter table public.commandes    enable row level security;

-- ---------------------------------------------------------------------
-- 3. UTILISATEURS : chacun son profil, l'admin voit tout.
-- ---------------------------------------------------------------------
create policy "utilisateurs : lire son profil (admin : tous)"
  on public.utilisateurs for select to authenticated
  using (id = (select auth.uid()) or public.mon_type() = 'admin');

-- À l'inscription : seulement sa propre ligne, et jamais le type admin.
create policy "utilisateurs : créer son profil vendeur ou acheteur"
  on public.utilisateurs for insert to authenticated
  with check (id = (select auth.uid()) and type in ('vendeur', 'acheteur'));

create policy "utilisateurs : modifier son profil (admin : tous)"
  on public.utilisateurs for update to authenticated
  using      (id = (select auth.uid()) or public.mon_type() = 'admin')
  with check (id = (select auth.uid()) or public.mon_type() = 'admin');

create policy "utilisateurs : supprimer (admin seulement)"
  on public.utilisateurs for delete to authenticated
  using (public.mon_type() = 'admin');

-- Personne ne peut changer son propre type (ni son identifiant) depuis le
-- site. Seul un admin le peut. Depuis l'éditeur SQL (toi), c'est permis :
-- c'est la seule façon de nommer un admin.
create or replace function public.bloquer_changement_type()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null
     and coalesce(public.mon_type(), '') <> 'admin'
     and (new.type is distinct from old.type or new.id is distinct from old.id) then
    raise exception 'Modification du type de compte interdite';
  end if;
  return new;
end;
$$;

drop trigger if exists bloquer_changement_type on public.utilisateurs;
create trigger bloquer_changement_type
  before update on public.utilisateurs
  for each row execute function public.bloquer_changement_type();

-- ---------------------------------------------------------------------
-- 4. VUE PUBLIQUE DES VENDEURS : prénom, nom et zone seulement,
--    pour afficher le vendeur dans le catalogue. Ni téléphone, ni e-mail.
--    La vue lit la table avec les droits de son propriétaire : elle montre
--    ces 4 colonnes à tous, et rien d'autre.
-- ---------------------------------------------------------------------
create or replace view public.vendeurs_publics as
  select id, prenom, nom, zone
  from public.utilisateurs
  where type = 'vendeur';

-- Lecture seule : on retire tous les droits puis on rend seulement la lecture
-- (sinon on pourrait modifier « utilisateurs » à travers la vue).
revoke all on public.vendeurs_publics from anon, authenticated;
grant select on public.vendeurs_publics to anon, authenticated;

-- ---------------------------------------------------------------------
-- 5. PRODUITS : lecture publique, écriture par le vendeur propriétaire.
-- ---------------------------------------------------------------------
create policy "produits : lecture publique"
  on public.produits for select to anon, authenticated
  using (true);

create policy "produits : un vendeur crée ses produits"
  on public.produits for insert to authenticated
  with check (vendeur_id = (select auth.uid()) and public.mon_type() = 'vendeur');

create policy "produits : le propriétaire modifie (admin : tous)"
  on public.produits for update to authenticated
  using      (vendeur_id = (select auth.uid()) or public.mon_type() = 'admin')
  with check (vendeur_id = (select auth.uid()) or public.mon_type() = 'admin');

create policy "produits : le propriétaire supprime (admin : tous)"
  on public.produits for delete to authenticated
  using (vendeur_id = (select auth.uid()) or public.mon_type() = 'admin');

-- ---------------------------------------------------------------------
-- 6. COMMANDES : chacun voit les siennes, rien pour les visiteurs.
-- ---------------------------------------------------------------------
create policy "commandes : acheteur, vendeur concerné ou admin"
  on public.commandes for select to authenticated
  using (acheteur_id = (select auth.uid())
         or vendeur_id = (select auth.uid())
         or public.mon_type() = 'admin');

create policy "commandes : un connecté commande à son nom"
  on public.commandes for insert to authenticated
  with check (acheteur_id = (select auth.uid()));

create policy "commandes : modifier (admin seulement)"
  on public.commandes for update to authenticated
  using      (public.mon_type() = 'admin')
  with check (public.mon_type() = 'admin');

create policy "commandes : supprimer (admin seulement)"
  on public.commandes for delete to authenticated
  using (public.mon_type() = 'admin');

-- La base recalcule elle-même le vendeur, le montant, la commission (5 %)
-- et le statut à partir du produit : le navigateur ne décide plus du prix.
create or replace function public.preparer_commande()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  p record;
begin
  select vendeur_id, prix into p from public.produits where id = new.produit_id;
  if not found then
    raise exception 'Produit introuvable';
  end if;
  if new.quantite is null or new.quantite <= 0 then
    raise exception 'Quantité invalide';
  end if;
  new.vendeur_id    := p.vendeur_id;
  new.montant_total := p.prix * new.quantite;
  new.commission    := round(p.prix * new.quantite * 0.05);
  new.statut        := 'en_attente';
  new.created_at    := now();
  return new;
end;
$$;

drop trigger if exists preparer_commande on public.commandes;
create trigger preparer_commande
  before insert on public.commandes
  for each row execute function public.preparer_commande();

commit;
