-- =====================================================================
-- Sen Tolbi · Tâche 11 · Commande complète (stock, produits retirés, livraison)
-- À coller en entier dans Supabase > SQL Editor, puis Run.
-- Tout est entre begin et commit : si une ligne échoue, rien n'est appliqué.
-- Retour en arrière : 2026-10-30-t11-retour-arriere.sql
-- =====================================================================
begin;

-- ---------------------------------------------------------------------
-- 1. PRODUITS : nouvelle colonne « en_vente ».
--    true  = le produit est visible et commandable (valeur par défaut) ;
--    false = le vendeur l'a retiré du catalogue.
--    On retire un produit au lieu de le supprimer : un produit déjà commandé
--    ne peut pas être supprimé (les commandes gardent le lien vers lui).
--    La règle T6 « produits : le propriétaire modifie (admin : tous) »
--    permet déjà au vendeur de changer cette colonne sur ses seuls produits.
-- ---------------------------------------------------------------------
alter table public.produits
  add column if not exists en_vente boolean not null default true;

-- Filet de sécurité : le stock ne peut jamais être négatif, même si
-- quelqu'un modifie la quantité à la main.
alter table public.produits drop constraint if exists produits_quantite_positive;
alter table public.produits
  add constraint produits_quantite_positive check (quantite >= 0);

-- ---------------------------------------------------------------------
-- 2. COMMANDES : trois nouvelles colonnes pour la livraison.
--    mode_livraison    : 'livraison' (à domicile) ou 'retrait' (chez le producteur)
--    adresse_livraison : adresse ou quartier (obligatoire pour 'livraison')
--    note_acheteur     : note facultative de l'acheteur pour le vendeur
--    Les anciennes commandes gardent ces colonnes vides.
--    Qui peut les lire : la règle T6 « commandes : acheteur, vendeur concerné
--    ou admin » s'applique à toute la ligne, donc aux nouvelles colonnes.
--    Les visiteurs (non connectés) n'ont aucune règle sur commandes : rien.
-- ---------------------------------------------------------------------
alter table public.commandes
  add column if not exists mode_livraison    text,
  add column if not exists adresse_livraison text,
  add column if not exists note_acheteur     text;

alter table public.commandes drop constraint if exists commandes_mode_livraison_check;
alter table public.commandes
  add constraint commandes_mode_livraison_check
  check (mode_livraison in ('livraison', 'retrait'));

-- ---------------------------------------------------------------------
-- 3. Le déclencheur « preparer_commande » (T6) est complété.
--    Il garde exactement le même calcul du vendeur, du montant, de la
--    commission (5 %) et du statut. Il ajoute, avant ce calcul :
--      a) la vérification du produit (en vente, pas épuisé, stock suffisant) ;
--      b) la vérification de la livraison (mode, adresse, longueur de la note) ;
--      c) la baisse du stock.
--
--    Deux commandes en même temps ne peuvent pas passer le stock sous zéro :
--    « select … for update » verrouille la ligne du produit. Si deux acheteurs
--    commandent le même produit à la même seconde, le second attend que la
--    commande du premier soit finie, puis relit le stock déjà baissé.
--    S'il ne reste plus assez, sa commande est refusée.
--    En plus, la règle « produits_quantite_positive » ci-dessus refuse
--    tout stock négatif.
--
--    Un panier de plusieurs produits est envoyé en une seule fois : si un
--    seul article est refusé, aucun article n'est enregistré et aucun stock
--    ne bouge (tout ou rien).
-- ---------------------------------------------------------------------
create or replace function public.preparer_commande()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  p record;
begin
  if new.quantite is null or new.quantite <= 0 then
    raise exception 'Quantité invalide';
  end if;

  -- a) Produit : on verrouille sa ligne jusqu'à la fin de la commande.
  select vendeur_id, prix, nom, quantite, unite, en_vente
    into p
    from public.produits
   where id = new.produit_id
     for update;
  if not found then
    raise exception 'Produit introuvable';
  end if;
  if not p.en_vente then
    raise exception 'Le produit « % » a été retiré du catalogue.', p.nom;
  end if;
  if p.quantite <= 0 then
    raise exception 'Le produit « % » est épuisé.', p.nom;
  end if;
  if new.quantite > p.quantite then
    raise exception 'Stock insuffisant pour « % » : il reste % %.', p.nom, p.quantite, p.unite;
  end if;

  -- b) Livraison : on nettoie les espaces, puis on vérifie.
  new.adresse_livraison := nullif(btrim(new.adresse_livraison), '');
  new.note_acheteur     := nullif(btrim(new.note_acheteur), '');
  if new.mode_livraison is null or new.mode_livraison not in ('livraison', 'retrait') then
    raise exception 'Choisissez un mode de livraison : livraison à domicile ou retrait chez le producteur.';
  end if;
  if new.mode_livraison = 'livraison' and new.adresse_livraison is null then
    raise exception 'L''adresse de livraison est obligatoire pour une livraison à domicile.';
  end if;
  if length(new.adresse_livraison) > 300 then
    raise exception 'L''adresse est trop longue (300 caractères au maximum).';
  end if;
  if length(new.note_acheteur) > 500 then
    raise exception 'La note pour le vendeur est trop longue (500 caractères au maximum).';
  end if;

  -- c) Baisse du stock (la ligne est déjà verrouillée).
  update public.produits
     set quantite = quantite - new.quantite
   where id = new.produit_id;

  -- Calcul inchangé depuis la T6.
  new.vendeur_id    := p.vendeur_id;
  new.montant_total := p.prix * new.quantite;
  new.commission    := round(p.prix * new.quantite * 0.05);
  new.statut        := 'en_attente';
  new.created_at    := now();
  return new;
end;
$$;

-- Le déclencheur lui-même existe déjà (T6) ; on le recrée par sécurité.
drop trigger if exists preparer_commande on public.commandes;
create trigger preparer_commande
  before insert on public.commandes
  for each row execute function public.preparer_commande();

commit;
