-- =====================================================================
-- Sen Tolbi · Tâche 11 · RETOUR EN ARRIÈRE
-- Remet la base comme après la T6. À utiliser seulement si les commandes
-- ne marchent plus.
-- Attention :
--   - le mode de livraison, l'adresse et la note des commandes passées
--     depuis la T11 sont effacés (les colonnes sont supprimées) ;
--   - le stock déjà baissé par les commandes n'est PAS remis ;
--   - les produits retirés (en_vente = false) redeviennent visibles.
-- Tout est entre begin et commit : si une ligne échoue, rien n'est appliqué.
-- =====================================================================
begin;

-- 1. Remettre le déclencheur de la T6 tel quel (sans stock ni livraison).
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

-- 2. Retirer les colonnes de livraison.
alter table public.commandes drop constraint if exists commandes_mode_livraison_check;
alter table public.commandes
  drop column if exists mode_livraison,
  drop column if exists adresse_livraison,
  drop column if exists note_acheteur;

-- 3. Retirer la colonne « en_vente » et le filet « stock jamais négatif ».
alter table public.produits drop constraint if exists produits_quantite_positive;
alter table public.produits drop column if exists en_vente;

commit;
