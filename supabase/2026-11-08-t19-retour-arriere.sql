-- =====================================================================
-- Sen Tolbi · Tâche 19 · Retour en arrière
-- Remet created_at en « timestamp without time zone », valeurs en UTC,
-- exactement comme avant la T19. Les heures ne bougent pas.
-- =====================================================================

begin;

alter table public.commandes
  alter column created_at type timestamp without time zone
  using created_at at time zone 'UTC';

alter table public.produits
  alter column created_at type timestamp without time zone
  using created_at at time zone 'UTC';

alter table public.utilisateurs
  alter column created_at type timestamp without time zone
  using created_at at time zone 'UTC';

-- Contrôle : les 3 lignes doivent afficher « timestamp without time zone ».
select table_name, data_type, column_default
  from information_schema.columns
 where table_schema = 'public'
   and column_name = 'created_at'
 order by table_name;

commit;
