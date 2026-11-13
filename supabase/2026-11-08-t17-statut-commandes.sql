-- =====================================================================
-- Sen Tolbi · Tâche 17 · Statut et annulation des commandes
-- ÉTAPE 1 sur 2 : le mécanisme commun (identique pour les deux variantes).
--
-- NE PAS APPLIQUER avant la décision D1 / D2 de la réunion du 8/11.
-- Ordre : 1) ce fichier ; 2) UN SEUL des deux fichiers de variante :
--   - 2026-11-08-t17-variante-a-vendeur-confirme.sql
--   - 2026-11-08-t17-variante-b-equipe-confirme.sql
-- Retour en arrière : 2026-11-08-t17-retour-arriere.sql
--
-- À coller en entier dans Supabase > SQL Editor, puis Run.
-- Tout est entre begin et commit : si une ligne échoue, rien n'est appliqué.
--
-- Ce que ce fichier fait seul (sans variante) : RIEN ne change pour les
-- utilisateurs. La table des droits est vide, donc personne ne peut encore
-- changer un statut (comme aujourd'hui). C'est la variante qui donne les droits.
-- =====================================================================
begin;

-- ---------------------------------------------------------------------
-- 1. Liste fermée des statuts.
--    Aujourd'hui « statut » est un texte libre. On fixe les 4 valeurs :
--      en_attente  (commande reçue, valeur donnée par preparer_commande)
--      confirmee   (le vendeur ou l'équipe a accepté la commande)
--      livree      (la commande est remise à l'acheteur, fin)
--      annulee     (la commande est annulée, le stock est remis, fin)
--    Les commandes existantes doivent déjà avoir une de ces valeurs
--    (le 8/11 : 0 commande en base, donc aucun problème).
-- ---------------------------------------------------------------------
update public.commandes set statut = 'en_attente' where statut is null;
alter table public.commandes alter column statut set not null;
alter table public.commandes
  add constraint commandes_statut_check
  check (statut in ('en_attente', 'confirmee', 'livree', 'annulee'));

-- ---------------------------------------------------------------------
-- 2. Table des droits : « qui peut faire passer une commande de quel
--    statut à quel statut ».
--      role = 'acheteur' : l'acheteur de cette commande
--      role = 'vendeur'  : le vendeur de cette commande
--      role = 'admin'    : un compte de type admin (l'équipe Sen Tolbi)
--    La contrainte « passage_autorise » liste les seuls passages possibles,
--    quelle que soit la variante :
--      en_attente → confirmee → livree
--      en_attente → annulee
--      confirmee  → annulee
--    « livree » et « annulee » sont définitifs : on n'en sort plus.
--    Changer de variante plus tard = ajouter ou retirer des lignes ici,
--    sans toucher à la fonction.
--    RLS activé sans aucune règle : le site ne peut ni lire ni modifier
--    cette table ; seule la fonction (security definer) la lit.
-- ---------------------------------------------------------------------
create table public.droits_statut_commande (
  role         text not null check (role in ('acheteur', 'vendeur', 'admin')),
  statut_avant text not null,
  statut_apres text not null,
  primary key (role, statut_avant, statut_apres),
  constraint passage_autorise check (
    (statut_avant, statut_apres) in (
      ('en_attente', 'confirmee'),
      ('confirmee',  'livree'),
      ('en_attente', 'annulee'),
      ('confirmee',  'annulee')
    )
  )
);
alter table public.droits_statut_commande enable row level security;
revoke all on public.droits_statut_commande from anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. La fonction appelée par le site :
--      changer_statut_commande(id de la commande, nouveau statut)
--    Depuis le site (JavaScript) :
--      supabase.rpc('changer_statut_commande',
--        { p_commande_id: '…', p_nouveau_statut: 'confirmee' })
--    Elle renvoie le nouveau statut, ou une erreur en français.
--
--    Ce qu'elle fait, dans l'ordre :
--      a) verrouille la commande (deux clics en même temps ne font pas
--         deux annulations, donc pas deux retours de stock) ;
--      b) refuse si la personne n'est ni l'acheteur, ni le vendeur, ni admin
--         (message « Commande introuvable » : on ne dit pas qu'elle existe) ;
--      c) refuse un statut inconnu, un statut identique, un passage
--         impossible (ex. livree → en_attente) ;
--      d) refuse si la table des droits ne donne pas ce passage à cette
--         personne ;
--      e) en cas d'annulation : remet la quantité commandée dans le stock
--         du produit (même si le produit a été retiré du catalogue :
--         il reste retiré, mais son stock redevient juste) ;
--      f) écrit le nouveau statut.
-- ---------------------------------------------------------------------
create or replace function public.changer_statut_commande(
  p_commande_id    uuid,
  p_nouveau_statut text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  c        record;
  moi      uuid := (select auth.uid());
  mes_roles text[] := '{}';
  libelles constant jsonb := '{"en_attente":"en attente","confirmee":"confirmée","livree":"livrée","annulee":"annulée"}';
begin
  if moi is null then
    raise exception 'Connectez-vous pour modifier une commande.';
  end if;

  -- a) Commande verrouillée jusqu'à la fin.
  select id, acheteur_id, vendeur_id, produit_id, quantite, statut
    into c
    from public.commandes
   where id = p_commande_id
     for update;

  -- b) Qui suis-je pour cette commande ?
  if found then
    if c.acheteur_id = moi then mes_roles := array_append(mes_roles, 'acheteur'); end if;
    if c.vendeur_id  = moi then mes_roles := array_append(mes_roles, 'vendeur'); end if;
    if public.mon_type() = 'admin' then mes_roles := array_append(mes_roles, 'admin'); end if;
  end if;
  if not found or cardinality(mes_roles) = 0 then
    raise exception 'Commande introuvable.';
  end if;

  -- c) Statut demandé valable ?
  if p_nouveau_statut is null or not (libelles ? p_nouveau_statut) then
    raise exception 'Statut inconnu : %.', coalesce(p_nouveau_statut, '(vide)');
  end if;
  if p_nouveau_statut = c.statut then
    raise exception 'La commande est déjà %.', libelles->>c.statut;
  end if;
  if c.statut in ('livree', 'annulee') then
    raise exception 'La commande est déjà %, elle ne peut plus changer.', libelles->>c.statut;
  end if;
  if not ((c.statut, p_nouveau_statut) in (
            ('en_attente', 'confirmee'), ('confirmee', 'livree'),
            ('en_attente', 'annulee'),   ('confirmee', 'annulee'))) then
    raise exception 'Passage impossible : une commande % ne peut pas devenir %.',
      libelles->>c.statut, libelles->>p_nouveau_statut;
  end if;

  -- d) Ai-je le droit de faire ce passage ?
  if not exists (
    select 1 from public.droits_statut_commande d
     where d.role = any (mes_roles)
       and d.statut_avant = c.statut
       and d.statut_apres = p_nouveau_statut
  ) then
    raise exception 'Vous ne pouvez pas faire passer cette commande de « % » à « % ».',
      libelles->>c.statut, libelles->>p_nouveau_statut;
  end if;

  -- e) Annulation : le stock revient.
  if p_nouveau_statut = 'annulee' then
    update public.produits
       set quantite = quantite + c.quantite
     where id = c.produit_id;
  end if;

  -- f) Nouveau statut. Le « laissez-passer » ci-dessous dit au garde
  --    (point 4) que le changement vient bien de cette fonction.
  perform set_config('sen_tolbi.changement_statut', 'oui', true);
  update public.commandes set statut = p_nouveau_statut where id = c.id;
  perform set_config('sen_tolbi.changement_statut', '', true);

  return p_nouveau_statut;
end;
$$;

-- Seuls les connectés peuvent l'appeler (les visiteurs non).
revoke execute on function public.changer_statut_commande(uuid, text) from public;
revoke execute on function public.changer_statut_commande(uuid, text) from anon;
grant  execute on function public.changer_statut_commande(uuid, text) to authenticated;

-- ---------------------------------------------------------------------
-- 4. Garde : depuis le site, le statut ne change QUE par la fonction.
--    Sans ce garde, un futur admin pourrait changer « statut » directement
--    (la règle T6 « commandes : modifier (admin seulement) » le permet)
--    et le stock ne serait pas remis.
--    Depuis l'éditeur SQL (toi, sans connexion au site) le garde laisse
--    passer, comme pour bloquer_changement_type. Attention : un changement
--    de statut fait à la main dans l'éditeur ne remet PAS le stock.
-- ---------------------------------------------------------------------
create or replace function public.proteger_statut_commande()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.statut is distinct from old.statut
     and (select auth.uid()) is not null
     and coalesce(current_setting('sen_tolbi.changement_statut', true), '') <> 'oui' then
    raise exception 'Le statut d''une commande se change avec changer_statut_commande.';
  end if;
  return new;
end;
$$;

revoke execute on function public.proteger_statut_commande() from public;
revoke execute on function public.proteger_statut_commande() from anon;
revoke execute on function public.proteger_statut_commande() from authenticated;

drop trigger if exists proteger_statut_commande on public.commandes;
create trigger proteger_statut_commande
  before update on public.commandes
  for each row execute function public.proteger_statut_commande();

commit;
