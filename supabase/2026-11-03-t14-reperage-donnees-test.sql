-- =====================================================================
-- Sen Tolbi · Tâche 14 · Étape 1 : repérage des données de test
-- LECTURE SEULE : cette requête ne modifie rien (uniquement des SELECT).
-- À coller dans Supabase > SQL Editor > New query, puis « Run ».
-- Une seule requête, un seul tableau de résultat, trié par rubrique.
--
-- Colonnes : rubrique · quoi · id · detail · date (UTC) · proposition
-- « proposition » n'est qu'un avis : rien n'est supprimé à cette étape.
-- =====================================================================

with
-- Comptes de test (adresses « +… » de Coumba utilisées pendant les tests)
comptes_test as (
  select u.id, u.email
  from public.utilisateurs u
  where lower(u.email) in (
    'coumba.thiam148+vendeur@gmail.com',
    'coumba.thiam148+acheteur@gmail.com',
    'coumba.thiam148+test6@gmail.com',
    'coumba.thiam148+test7@gmail.com',
    'coumba.thiam148+test8@gmail.com'
  )
)

-- 0. Comptages actuels (pour comparer avant / après)
select '0 · Comptage' as rubrique, 'profils (utilisateurs)' as quoi, null::text as id,
       count(*)::text as detail, null::text as date, '' as proposition
from public.utilisateurs
union all
select '0 · Comptage', 'comptes de connexion (auth.users)', null, count(*)::text, null, ''
from auth.users
union all
select '0 · Comptage', 'produits', null, count(*)::text, null, ''
from public.produits
union all
select '0 · Comptage', 'commandes', null, count(*)::text, null, ''
from public.commandes

-- 1. Comptes de test : profil + compte de connexion
union all
select '1 · Compte de test',
       u.prenom || ' ' || u.nom || ' (' || u.type || ')',
       u.id::text,
       u.email || case when a.id is null then ' · PAS de compte de connexion'
                       else ' · compte de connexion OK' end,
       u.created_at::text,
       case u.email
         when 'coumba.thiam148+vendeur@gmail.com'  then 'garder ? (vendeur de test)'
         when 'coumba.thiam148+acheteur@gmail.com' then 'garder ? (acheteur de test)'
         else 'supprimer ?'
       end
from public.utilisateurs u
join comptes_test t on t.id = u.id
left join auth.users a on a.id = u.id

-- 2. Produits des comptes de test (dont TEST TOMATES et TEST T11)
union all
select '2 · Produit de test',
       p.nom || ' · ' || p.quantite || ' ' || p.unite || ' · ' || p.prix || ' FCFA'
         || case when p.en_vente then ' · en vente' else ' · retiré' end,
       p.id::text,
       'vendeur : ' || t.email,
       p.created_at::text,
       'supprimer ?'
from public.produits p
join comptes_test t on t.id = p.vendeur_id

-- 3. Produits « Maad » et « Fraises » de Coumba
union all
select '3 · Produit de Coumba',
       p.nom || ' · ' || p.quantite || ' ' || p.unite || ' · ' || p.prix || ' FCFA',
       p.id::text,
       'vendeur : ' || coalesce(u.email, '?'),
       p.created_at::text,
       'à valider par Coumba'
from public.produits p
left join public.utilisateurs u on u.id = p.vendeur_id
where p.nom ilike any (array['%maad%', '%fraise%'])

-- 4. Toutes les commandes, avec qui a commandé quoi
--    STL-383970 = la commande du 21/10 à 21:49 (le site calculait ce numéro
--    avec l'heure de l'ordinateur, il n'était pas enregistré dans la base).
union all
select '4 · Commande',
       coalesce(p.nom, '(produit disparu)') || ' × ' || c.quantite
         || ' · ' || c.montant_total || ' FCFA · ' || coalesce(c.statut, '?'),
       c.id::text,
       'acheteur : ' || coalesce(ua.email, '?') || ' · vendeur : ' || coalesce(uv.email, '?'),
       c.created_at::text,
       case
         when c.created_at between '2026-10-21 21:49:00' and '2026-10-21 21:50:00'
           then 'supprimer ? (STL-383970)'
         when c.created_at between '2026-10-26 08:18:00' and '2026-10-26 08:19:00'
           then 'supprimer ? (commande du 26/10 08:18)'
         when c.acheteur_id in (select id from comptes_test)
           or c.vendeur_id  in (select id from comptes_test)
           then 'supprimer ? (tests)'
         else 'à décider (commande ancienne)'
       end
from public.commandes c
left join public.produits p      on p.id  = c.produit_id
left join public.utilisateurs ua on ua.id = c.acheteur_id
left join public.utilisateurs uv on uv.id = c.vendeur_id

-- 5. Profils sans compte de connexion (personne ne peut s'y connecter)
union all
select '5 · Profil sans compte de connexion',
       u.prenom || ' ' || u.nom || ' (' || u.type || ')',
       u.id::text,
       coalesce(u.email, '(pas d''e-mail)')
         || ' · ' || (select count(*) from public.produits  p where p.vendeur_id = u.id) || ' produit(s)'
         || ' · ' || (select count(*) from public.commandes c where c.acheteur_id = u.id or c.vendeur_id = u.id) || ' commande(s)',
       u.created_at::text,
       'supprimer ?'
from public.utilisateurs u
left join auth.users a on a.id = u.id
where a.id is null

-- 6. Comptes de connexion sans profil (inscription inachevée ?)
union all
select '6 · Compte de connexion sans profil',
       'auth.users',
       a.id::text,
       a.email,
       a.created_at::text,
       'à vérifier (peut être un compte de l''équipe)'
from auth.users a
left join public.utilisateurs u on u.id = a.id
where u.id is null

-- 7. Les 3 anciennes règles « Accès public … » désactivées (condition false)
union all
select '7 · Ancienne règle désactivée',
       pol.policyname || ' (' || pol.cmd || ')',
       pol.tablename,
       'using : ' || coalesce(pol.qual, '-') || ' · with check : ' || coalesce(pol.with_check, '-'),
       null,
       'supprimer ? (ne sert plus)'
from pg_policies pol
where pol.schemaname = 'public'
  and pol.policyname like 'Accès public%'

order by 1, 5;
