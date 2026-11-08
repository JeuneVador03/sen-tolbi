-- Tests T17 communs (mécanisme seul, table des droits vide). Postgres local uniquement.
create schema tst;
create table tst.resultats (n serial, test text, ok boolean, detail text);

-- essai(qui, requête, attendu) : lance la requête comme ce compte connecté
-- (rôle authenticated, comme le site). attendu = 'ok' ou un morceau du message d'erreur.
create procedure tst.essai(qui uuid, requete text, attendu text, test text)
language plpgsql as $$
declare msg text := 'ok';
begin
  perform set_config('request.jwt.claim.sub', coalesce(qui::text, ''), true);
  if qui is null then execute 'set local role anon'; else execute 'set local role authenticated'; end if;
  begin
    execute requete;
  exception when others then msg := sqlerrm;
  end;
  execute 'reset role';
  perform set_config('request.jwt.claim.sub', '', true);
  insert into tst.resultats(test, ok, detail)
  values (test, (attendu = 'ok' and msg = 'ok') or (attendu <> 'ok' and position(attendu in msg) > 0), msg);
end $$;

create procedure tst.verifier(condition boolean, test text, detail text default '')
language plpgsql as $$
begin insert into tst.resultats(test, ok, detail) values (test, coalesce(condition, false), detail); end $$;

create function tst.statut(id uuid) returns text language sql as $$ select statut from public.commandes where id = $1 $$;
create function tst.stock(id uuid) returns int language sql as $$ select quantite from public.produits where id = $1 $$;
create function tst.en_vente(id uuid) returns boolean language sql as $$ select en_vente from public.produits where id = $1 $$;
create function tst.type_de(id uuid) returns text language sql as $$ select type from public.utilisateurs where id = $1 $$;

-- Comptes de test : V vendeur, V2 autre vendeur, A acheteur, A2 autre acheteur, E (futur admin).
insert into auth.users values
 ('00000000-0000-0000-0000-00000000000a','v@test'), ('00000000-0000-0000-0000-00000000000b','v2@test'),
 ('00000000-0000-0000-0000-00000000000c','a@test'), ('00000000-0000-0000-0000-00000000000d','a2@test'),
 ('00000000-0000-0000-0000-00000000000e','e@test');
insert into public.utilisateurs (id, prenom, nom, telephone, mot_de_passe, type) values
 ('00000000-0000-0000-0000-00000000000a','V','Vendeur','1','x','vendeur'),
 ('00000000-0000-0000-0000-00000000000b','V2','Vendeur','2','x','vendeur'),
 ('00000000-0000-0000-0000-00000000000c','A','Acheteur','3','x','acheteur'),
 ('00000000-0000-0000-0000-00000000000d','A2','Acheteur','4','x','acheteur'),
 ('00000000-0000-0000-0000-00000000000e','E','Equipe','5','x','acheteur');
insert into public.produits (id, vendeur_id, nom, categorie, prix, quantite, unite) values
 ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-00000000000a','Tomates','legumes',500,10,'kg');

-- Commande passée par A comme le site (le déclencheur T11 baisse le stock).
create procedure tst.commander(cid uuid, qte int) language plpgsql as $$
begin
  call tst.essai('00000000-0000-0000-0000-00000000000c',
    format($q$insert into public.commandes (id, acheteur_id, produit_id, quantite, montant_total, commission, mode_livraison)
              values (%L, '00000000-0000-0000-0000-00000000000c', '10000000-0000-0000-0000-000000000001', %s, 0, 0, 'retrait')$q$, cid, qte),
    'ok', 'commande ' || cid || ' passée');
end $$;

call tst.commander('20000000-0000-0000-0000-000000000001', 2);
call tst.verifier(tst.stock('10000000-0000-0000-0000-000000000001') = 8, 'C1 : stock 10 → 8 après commande de 2');
call tst.verifier(tst.statut('20000000-0000-0000-0000-000000000001') = 'en_attente', 'C2 : nouvelle commande en_attente');

-- Sans variante : personne n'a de droit.
call tst.essai('00000000-0000-0000-0000-00000000000a', $$select public.changer_statut_commande('20000000-0000-0000-0000-000000000001','confirmee')$$,
  'Vous ne pouvez pas', 'C3 : sans variante, le vendeur ne peut pas confirmer');
call tst.essai('00000000-0000-0000-0000-00000000000c', $$select public.changer_statut_commande('20000000-0000-0000-0000-000000000001','annulee')$$,
  'Vous ne pouvez pas', 'C4 : sans variante, l''acheteur ne peut pas annuler');
call tst.essai(null, $$select public.changer_statut_commande('20000000-0000-0000-0000-000000000001','annulee')$$,
  'permission denied', 'C5 : un visiteur ne peut pas appeler la fonction');
call tst.essai('00000000-0000-0000-0000-00000000000d', $$select public.changer_statut_commande('20000000-0000-0000-0000-000000000001','annulee')$$,
  'Commande introuvable', 'C6 : un autre acheteur : « Commande introuvable »');
call tst.essai('00000000-0000-0000-0000-00000000000b', $$select public.changer_statut_commande('20000000-0000-0000-0000-000000000001','annulee')$$,
  'Commande introuvable', 'C7 : un autre vendeur : « Commande introuvable »');
call tst.essai('00000000-0000-0000-0000-00000000000c', $$select public.changer_statut_commande('29999999-0000-0000-0000-000000000000','annulee')$$,
  'Commande introuvable', 'C8 : commande qui n''existe pas');
call tst.essai('00000000-0000-0000-0000-00000000000c', $$select public.changer_statut_commande('20000000-0000-0000-0000-000000000001','payee')$$,
  'Statut inconnu', 'C9 : statut inconnu refusé');
call tst.essai('00000000-0000-0000-0000-00000000000c', $$select public.changer_statut_commande('20000000-0000-0000-0000-000000000001','en_attente')$$,
  'déjà en attente', 'C10 : même statut refusé');
call tst.essai('00000000-0000-0000-0000-00000000000c', $$select * from public.droits_statut_commande$$,
  'permission denied', 'C11 : le site ne peut pas lire la table des droits');
call tst.essai('00000000-0000-0000-0000-00000000000a', $$insert into public.droits_statut_commande values ('vendeur','en_attente','confirmee')$$,
  'permission denied', 'C12 : le site ne peut pas se donner des droits');
call tst.essai('00000000-0000-0000-0000-00000000000a', $$select public.proteger_statut_commande()$$,
  'permission denied', 'C13 : la fonction du garde n''est pas appelable');
-- Garde : connecté (uid présent) mais sans passer par la fonction.
do $$ begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', true);
  begin
    update public.commandes set statut = 'livree' where id = '20000000-0000-0000-0000-000000000001';
    call tst.verifier(false, 'C14 : le garde refuse un changement direct de statut');
  exception when others then
    call tst.verifier(sqlerrm like '%changer_statut_commande%', 'C14 : le garde refuse un changement direct de statut', sqlerrm);
  end;
  perform set_config('request.jwt.claim.sub', '', true);
end $$;
-- Contrainte : statut inconnu refusé même depuis l'éditeur SQL.
do $$ begin
  begin
    update public.commandes set statut = 'payee' where id = '20000000-0000-0000-0000-000000000001';
    call tst.verifier(false, 'C15 : la base refuse un statut hors liste');
  exception when check_violation then
    call tst.verifier(true, 'C15 : la base refuse un statut hors liste');
  end;
end $$;
-- Table des droits : passage impossible refusé.
do $$ begin
  begin
    insert into public.droits_statut_commande values ('admin','livree','en_attente');
    call tst.verifier(false, 'C16 : la table des droits refuse livree → en_attente');
  exception when check_violation then
    call tst.verifier(true, 'C16 : la table des droits refuse livree → en_attente');
  end;
end $$;
call tst.verifier(tst.statut('20000000-0000-0000-0000-000000000001') = 'en_attente'
              and tst.stock('10000000-0000-0000-0000-000000000001') = 8, 'C17 : rien n''a bougé après les refus');

create procedure tst.bilan(bloc text) language plpgsql as $$
declare r record; nb int; ko int;
begin
  for r in select * from tst.resultats where test like bloc || '%' order by n loop
    raise notice '% %  %', case when r.ok then 'OK ' else 'ÉCHEC' end, r.test, case when r.ok then '' else '→ ' || r.detail end;
  end loop;
  select count(*), count(*) filter (where not ok) into nb, ko from tst.resultats where test like bloc || '%';
  raise notice '== % : % tests, % échec(s)', bloc, nb, ko;
  if ko > 0 then raise exception 'Des tests ont échoué'; end if;
end $$;
call tst.bilan('C');
