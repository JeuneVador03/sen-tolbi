set timezone = 'Europe/Paris';
do $$
declare n int; r record;
begin
  -- 1. Les 3 colonnes sont en timestamptz, défaut now()
  select count(*) into n from information_schema.columns
   where table_schema='public' and column_name='created_at'
     and table_name in ('commandes','produits','utilisateurs')
     and data_type='timestamp with time zone' and column_default='now()';
  if n<>3 then raise exception 'T1 échoue : % colonnes converties', n; end if;
  raise notice 'T1 OK : 3 colonnes en timestamp with time zone, défaut now()';

  -- 2. Chaque ancienne valeur = même instant, lu comme UTC
  select count(*) into n from public.t19_avant a
   where (a.t='commandes'    and (select created_at from public.commandes    where id=a.id) <> (a.v||'+00')::timestamptz)
      or (a.t='produits'     and (select created_at from public.produits     where id=a.id) <> (a.v||'+00')::timestamptz)
      or (a.t='utilisateurs' and (select created_at from public.utilisateurs where id=a.id) <> (a.v||'+00')::timestamptz);
  if n<>0 then raise exception 'T2 échoue : % valeurs décalées', n; end if;
  raise notice 'T2 OK : anciennes valeurs gardées et lues comme UTC (session en heure de Paris)';

  -- 3. Exemple concret : commande du 21/10 21:49 UTC = 21:49 à Dakar, 23:49 à Paris (heure d''été finie le 25/10 → 22:49)
  select to_char(created_at at time zone 'Africa/Dakar','YYYY-MM-DD HH24:MI') d into r from public.commandes where id='cccccccc-cccc-cccc-cccc-cccccccccccc';
  if r.d<>'2026-10-21 21:49' then raise exception 'T3 échoue : %', r.d; end if;
  raise notice 'T3 OK : commande affichée 21:49 à Dakar';
end $$;

-- 4. Nouvelle commande via le vrai déclencheur, en tant qu'acheteur connecté
set role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222222',false);
insert into public.commandes(acheteur_id,produit_id,quantite,montant_total,commission,mode_livraison)
 values ('22222222-2222-2222-2222-222222222222','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',2,0,0,'retrait');
reset role;
do $$ declare n int; s int; begin
  select count(*) into n from public.commandes where quantite=2 and abs(extract(epoch from now()-created_at))<5;
  select quantite into s from public.produits where id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  if n<>1 or s<>8 then raise exception 'T4 échoue : % commande, stock %', n, s; end if;
  raise notice 'T4 OK : nouvelle commande enregistrée à l''heure exacte, stock 10 → 8';
end $$;

-- 5. Format renvoyé à la page (comme PostgREST, session UTC) : avec « +00:00 »
set timezone='UTC';
select 'T5 format JSON : ' || to_json(created_at)::text as info from public.commandes order by created_at limit 1;
-- 6. Les pages lisent created_at et vendeurs_publics marche toujours
select 'T6 vendeurs_publics : ' || count(*) from public.vendeurs_publics;
-- 7. Le retour en arrière T14 (insert depuis un ancien timestamp sans fuseau) passe toujours
create temp table vieux(created_at timestamp);
insert into vieux values ('2026-10-26 08:18:00');
alter table public.commandes disable trigger preparer_commande;
insert into public.commandes(acheteur_id,vendeur_id,produit_id,quantite,montant_total,commission,created_at)
 select '22222222-2222-2222-2222-222222222222','11111111-1111-1111-1111-111111111111','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',1,1,0,created_at from vieux;
alter table public.commandes enable trigger preparer_commande;
do $$ begin
  if not exists (select 1 from public.commandes where created_at='2026-10-26 08:18:00+00') then raise exception 'T7 échoue'; end if;
  raise notice 'T7 OK : insertion d''une ancienne heure sans fuseau (restauration T14, session UTC) correcte';
end $$;
