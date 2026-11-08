-- Données copiées de la base réelle (heures exactes lues le 08/11/2026), plus des commandes
-- passées par le vrai déclencheur preparer_commande. Session en heure de Paris exprès :
-- la conversion ne doit pas dépendre du fuseau de la session.
set timezone = 'Europe/Paris';
insert into auth.users(id,email) values
 ('11111111-1111-1111-1111-111111111111','vendeur@test'),('22222222-2222-2222-2222-222222222222','acheteur@test');
insert into public.utilisateurs(id,prenom,nom,telephone,mot_de_passe,type,zone,created_at) values
 ('11111111-1111-1111-1111-111111111111','V','Test','770000001','x','vendeur','Thiès','2026-07-14 00:57:34.988406'),
 ('22222222-2222-2222-2222-222222222222','A','Test','770000002','x','acheteur','Dakar','2026-10-21 21:47:05.504905');
insert into public.produits(id,vendeur_id,nom,categorie,prix,quantite,unite,created_at) values
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','11111111-1111-1111-1111-111111111111','Maad','Fruits',1000,10,'kg','2026-07-15 20:23:10.598948');
-- Une commande « ancienne » (heure UTC figée, déclencheur coupé comme à la restauration T14)
alter table public.commandes disable trigger preparer_commande;
insert into public.commandes(id,acheteur_id,vendeur_id,produit_id,quantite,montant_total,commission,statut,mode_livraison,created_at)
 values ('cccccccc-cccc-cccc-cccc-cccccccccccc','22222222-2222-2222-2222-222222222222','11111111-1111-1111-1111-111111111111',
         'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',1,1000,50,'en_attente','retrait','2026-10-21 21:49:00');
alter table public.commandes enable trigger preparer_commande;
-- Instantané des valeurs avant, en texte UTC
create table public.t19_avant as
 select 'commandes' t, id, created_at::text v from public.commandes
 union all select 'produits', id, created_at::text from public.produits
 union all select 'utilisateurs', id, created_at::text from public.utilisateurs;
