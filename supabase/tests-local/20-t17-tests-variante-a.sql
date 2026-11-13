-- Tests T17, variante A « le vendeur confirme ». Postgres local uniquement.
-- V = vendeur (…0a), A = acheteur (…0c), stock de départ du produit : 8 (C1 commandé 2).
\set V '00000000-0000-0000-0000-00000000000a'
\set A '00000000-0000-0000-0000-00000000000c'
\set P '10000000-0000-0000-0000-000000000001'
\set C1 '20000000-0000-0000-0000-000000000001'

call tst.essai(:'A', $$select public.changer_statut_commande('20000000-0000-0000-0000-000000000001','confirmee')$$, 'Vous ne pouvez pas', 'A1 : l''acheteur ne peut pas confirmer');
call tst.essai(:'V', $$select public.changer_statut_commande('20000000-0000-0000-0000-000000000001','livree')$$, 'Passage impossible', 'A2 : en attente → livrée directement : refusé');
call tst.essai(:'V', $$select public.changer_statut_commande('20000000-0000-0000-0000-000000000001','confirmee')$$, 'ok', 'A3 : le vendeur confirme');
call tst.verifier(tst.statut(:'C1') = 'confirmee', 'A4 : statut = confirmee');
call tst.essai(:'V', $$select public.changer_statut_commande('20000000-0000-0000-0000-000000000001','confirmee')$$, 'déjà confirmée', 'A5 : confirmer deux fois : refusé');
call tst.essai(:'A', $$select public.changer_statut_commande('20000000-0000-0000-0000-000000000001','annulee')$$, 'Vous ne pouvez pas', 'A6 : l''acheteur ne peut plus annuler après confirmation');
call tst.essai(:'V', $$select public.changer_statut_commande('20000000-0000-0000-0000-000000000001','annulee')$$, 'Vous ne pouvez pas', 'A7 : le vendeur ne peut plus annuler après confirmation');
call tst.essai(:'V', $$select public.changer_statut_commande('20000000-0000-0000-0000-000000000001','livree')$$, 'ok', 'A8 : le vendeur marque livrée');
call tst.essai(:'V', $$select public.changer_statut_commande('20000000-0000-0000-0000-000000000001','annulee')$$, 'ne peut plus changer', 'A9 : une commande livrée ne change plus');
call tst.verifier(tst.stock(:'P') = 8, 'A10 : livraison : le stock ne bouge pas (8)');

-- Annulation par l'acheteur : le stock revient.
call tst.commander('20000000-0000-0000-0000-000000000002', 3);
call tst.verifier(tst.stock(:'P') = 5, 'A11 : stock 8 → 5 après commande de 3');
call tst.essai(:'A', $$select public.changer_statut_commande('20000000-0000-0000-0000-000000000002','annulee')$$, 'ok', 'A12 : l''acheteur annule une commande en attente');
call tst.verifier(tst.stock(:'P') = 8, 'A13 : stock remis 5 → 8');
call tst.essai(:'A', $$select public.changer_statut_commande('20000000-0000-0000-0000-000000000002','annulee')$$, 'déjà annulée', 'A14 : annuler deux fois : refusé, stock non remis deux fois');
call tst.verifier(tst.stock(:'P') = 8, 'A15 : stock toujours 8');

-- Annulation par le vendeur, sur un produit retiré du catalogue entre-temps.
call tst.commander('20000000-0000-0000-0000-000000000003', 8);
call tst.verifier(tst.stock(:'P') = 0, 'A16 : stock 8 → 0 (épuisé)');
call tst.essai(:'V', $$update public.produits set en_vente = false where id = '10000000-0000-0000-0000-000000000001'$$, 'ok', 'A17 : le vendeur retire le produit');
call tst.essai(:'V', $$select public.changer_statut_commande('20000000-0000-0000-0000-000000000003','annulee')$$, 'ok', 'A18 : le vendeur refuse (annule) une commande en attente');
call tst.verifier(tst.stock(:'P') = 8 and not tst.en_vente(:'P'), 'A19 : stock remis à 8, produit toujours retiré');

-- Le vendeur ne peut pas contourner la fonction (aucune règle de modification pour lui).
call tst.essai(:'V', $$update public.commandes set statut = 'annulee' where id = '20000000-0000-0000-0000-000000000001'$$, 'ok', 'A20 : modification directe par le vendeur : 0 ligne touchée');
call tst.verifier(tst.statut(:'C1') = 'livree', 'A21 : statut toujours livree');
-- L'admin reste impossible en variante A.
do $$ begin
  begin
    update public.utilisateurs set type = 'admin' where id = '00000000-0000-0000-0000-00000000000e';
    call tst.verifier(false, 'A22 : variante A : la base refuse toujours le type admin');
  exception when check_violation then call tst.verifier(true, 'A22 : variante A : la base refuse toujours le type admin');
  end;
end $$;
call tst.bilan('A');
