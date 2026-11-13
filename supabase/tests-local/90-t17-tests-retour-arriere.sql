-- Après le retour en arrière : la base est comme avant la T17.
do $$ begin
  if to_regprocedure('public.changer_statut_commande(uuid,text)') is not null then raise exception 'fonction encore là'; end if;
  if to_regprocedure('public.proteger_statut_commande()') is not null then raise exception 'garde encore là'; end if;
  if to_regclass('public.droits_statut_commande') is not null then raise exception 'table encore là'; end if;
  if exists (select 1 from pg_constraint where conname = 'commandes_statut_check') then raise exception 'contrainte statut encore là'; end if;
  if (select pg_get_constraintdef(oid) from pg_constraint where conname = 'utilisateurs_type_check') like '%admin%' then raise exception 'admin encore accepté'; end if;
  if (select is_nullable from information_schema.columns where table_name='commandes' and column_name='statut') <> 'YES' then raise exception 'statut encore not null'; end if;
  -- La commande marche toujours comme avant.
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', true);
  update public.produits set en_vente = true;
  insert into public.commandes (acheteur_id, produit_id, quantite, montant_total, commission, mode_livraison)
  values ('00000000-0000-0000-0000-00000000000c', '10000000-0000-0000-0000-000000000001', 1, 0, 0, 'retrait');
  raise notice 'OK  R1-R7 : retour en arrière complet, la commande marche toujours';
end $$;
