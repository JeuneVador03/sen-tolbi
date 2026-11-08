set timezone = 'Europe/Paris';
do $$ declare n int; begin
  select count(*) into n from information_schema.columns
   where table_schema='public' and column_name='created_at'
     and table_name in ('commandes','produits','utilisateurs')
     and data_type='timestamp without time zone' and column_default='now()';
  if n<>3 then raise exception 'R1 échoue : %', n; end if;
  select count(*) into n from public.t19_avant a
   where (a.t='commandes'    and (select created_at::text from public.commandes    where id=a.id) <> a.v)
      or (a.t='produits'     and (select created_at::text from public.produits     where id=a.id) <> a.v)
      or (a.t='utilisateurs' and (select created_at::text from public.utilisateurs where id=a.id) <> a.v);
  if n<>0 then raise exception 'R2 échoue : % valeurs changées', n; end if;
  raise notice 'R1-R2 OK : retour en arrière, type d''origine et valeurs identiques à l''avant';
end $$;
