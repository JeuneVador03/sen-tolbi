-- Tests T17, variante B « l'équipe confirme ». Postgres local uniquement.
\set V '00000000-0000-0000-0000-00000000000a'
\set A '00000000-0000-0000-0000-00000000000c'
\set E '00000000-0000-0000-0000-00000000000e'
\set P '10000000-0000-0000-0000-000000000001'
\set C1 '20000000-0000-0000-0000-000000000001'

-- Inscription avec le type admin : toujours refusée (règle T6).
insert into auth.users values ('00000000-0000-0000-0000-0000000000ff','pirate@test');
call tst.essai('00000000-0000-0000-0000-0000000000ff', $$insert into public.utilisateurs (id,prenom,nom,telephone,mot_de_passe,type) values ('00000000-0000-0000-0000-0000000000ff','X','Y','9','x','admin')$$, 'row-level security', 'B1 : s''inscrire comme admin : refusé');
call tst.essai(:'A', $$update public.utilisateurs set type = 'admin' where id = '00000000-0000-0000-0000-00000000000c'$$, 'Modification du type de compte interdite', 'B2 : se promouvoir admin soi-même : refusé');
-- Nommer E admin depuis l'éditeur SQL (comme le point 3 du fichier).
update public.utilisateurs set type = 'admin' where id = (select id from auth.users where email = 'e@test');
call tst.verifier(tst.type_de(:'E') = 'admin', 'B3 : l''éditeur SQL peut nommer un admin');

call tst.essai(:'V', $$select public.changer_statut_commande('20000000-0000-0000-0000-000000000001','confirmee')$$, 'Vous ne pouvez pas', 'B4 : le vendeur ne peut pas confirmer');
call tst.essai(:'E', $$select public.changer_statut_commande('20000000-0000-0000-0000-000000000001','confirmee')$$, 'ok', 'B5 : l''équipe confirme');
call tst.essai(:'A', $$select public.changer_statut_commande('20000000-0000-0000-0000-000000000001','annulee')$$, 'Vous ne pouvez pas', 'B6 : l''acheteur ne peut plus annuler après confirmation');
call tst.essai(:'V', $$select public.changer_statut_commande('20000000-0000-0000-0000-000000000001','livree')$$, 'Vous ne pouvez pas', 'B7 : le vendeur ne peut pas marquer livrée');
call tst.essai(:'E', $$select public.changer_statut_commande('20000000-0000-0000-0000-000000000001','annulee')$$, 'ok', 'B8 : l''équipe annule une commande confirmée');
call tst.verifier(tst.stock(:'P') = 10, 'B9 : stock remis 8 → 10');

call tst.commander('20000000-0000-0000-0000-000000000002', 4);
call tst.essai(:'E', $$update public.commandes set statut = 'livree' where id = '20000000-0000-0000-0000-000000000002'$$, 'changer_statut_commande', 'B10 : l''admin ne peut pas changer le statut en direct (garde)');
call tst.essai(:'E', $$select public.changer_statut_commande('20000000-0000-0000-0000-000000000002','confirmee')$$, 'ok', 'B11 : l''équipe confirme');
call tst.essai(:'E', $$select public.changer_statut_commande('20000000-0000-0000-0000-000000000002','livree')$$, 'ok', 'B12 : l''équipe marque livrée');
call tst.verifier(tst.statut('20000000-0000-0000-0000-000000000002') = 'livree' and tst.stock(:'P') = 6, 'B13 : livrée, stock 6');

call tst.commander('20000000-0000-0000-0000-000000000003', 1);
call tst.essai(:'A', $$select public.changer_statut_commande('20000000-0000-0000-0000-000000000003','annulee')$$, 'ok', 'B14 : l''acheteur annule en attente');
call tst.commander('20000000-0000-0000-0000-000000000004', 1);
call tst.essai(:'V', $$select public.changer_statut_commande('20000000-0000-0000-0000-000000000004','annulee')$$, 'ok', 'B15 : le vendeur annule en attente');
call tst.verifier(tst.stock(:'P') = 6, 'B16 : stock remis après les deux annulations (6)');
call tst.essai(:'E', $$select count(*) from public.commandes$$, 'ok', 'B17 : l''admin lit toutes les commandes');

-- Le retour en arrière demande d'abord de retirer le type admin (documenté en tête du fichier).
update public.utilisateurs set type = 'acheteur' where type = 'admin';
call tst.bilan('B');
