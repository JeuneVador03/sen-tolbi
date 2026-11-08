-- =====================================================================
-- Sen Tolbi · Tâche 19 · Heures avec fuseau horaire
-- Passe created_at des tables commandes, produits et utilisateurs
-- de « timestamp without time zone » à « timestamp with time zone ».
--
-- Pourquoi : la base enregistre les heures en UTC mais sans le dire.
-- Une page ou un outil qui lit « 2026-10-21 21:49 » ne sait pas que c'est
-- de l'UTC (en France, ça donne 1 h d'écart). Avec le fuseau, la base
-- renvoie « 2026-10-21 21:49:00+00 » et plus personne ne peut se tromper.
--
-- Les anciennes valeurs SONT en UTC (vérifié le 08/11/2026 : le fuseau de
-- la base est UTC et les dates des profils correspondent à celles de
-- auth.users à 1 seconde près). On le dit explicitement avec
-- « at time zone 'UTC' » : le résultat ne dépend donc pas du fuseau
-- de la session qui lance ce SQL.
--
-- Vérifié avant (lecture seule, 08/11/2026) : aucune vue, règle (RLS),
-- index ou déclencheur ne dépend de ces colonnes. Seules dépendances :
-- les valeurs par défaut now(), qui restent valables.
-- preparer_commande fait « new.created_at := now() » : marche pareil.
-- vendeurs_publics et mon_type ne lisent pas created_at.
-- Le schéma de sauvegarde sauvegarde_t14 n'est pas touché.
--
-- Côté site : dashboard-acheteur.html et dashboard-agriculteur.html
-- acceptent déjà les deux formats (avec ou sans fuseau). catalogue.html,
-- dashboard-acheteur.html et dashboard-agriculteur.html ne font que trier
-- sur created_at : l'ordre ne change pas.
--
-- Tables minuscules (0 commande, 2 produits, 5 profils) : quelques
-- millisecondes. Tout ou rien : si une ligne échoue, rien ne change.
-- =====================================================================

begin;

alter table public.commandes
  alter column created_at type timestamp with time zone
  using created_at at time zone 'UTC';

alter table public.produits
  alter column created_at type timestamp with time zone
  using created_at at time zone 'UTC';

alter table public.utilisateurs
  alter column created_at type timestamp with time zone
  using created_at at time zone 'UTC';

-- Contrôle : les 3 lignes doivent afficher « timestamp with time zone »
-- et la valeur par défaut « now() ».
select table_name, data_type, column_default
  from information_schema.columns
 where table_schema = 'public'
   and column_name = 'created_at'
 order by table_name;

commit;
