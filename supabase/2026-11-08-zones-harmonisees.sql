-- Zones harmonisées (suite de la PR #21 de Coumba, tâche 11)
-- À lancer APRÈS la fusion de la PR #21, dans Supabase > SQL Editor.
-- Renomme les deux anciens noms de zone pour qu'ils correspondent à la liste commune :
--   « Plateau »          → « Plateau / Centre-ville »
--   « Ngor / Almadies »  → « Almadies / Ngor »
-- Le 08/11/2026 (lecture faite par Claude), AUCUN profil n'a encore ces anciens noms :
-- les deux UPDATE doivent donc annoncer 0 ligne. C'est une sécurité pour le cas où
-- quelqu'un s'inscrit avec l'ancienne liste avant la fusion.

begin;

-- 1. Avant : combien de profils par zone (à regarder)
select zone, count(*) from public.utilisateurs group by zone order by zone;

-- 2. Renommage (espaces autour du nom tolérés)
update public.utilisateurs set zone = 'Plateau / Centre-ville' where btrim(zone) = 'Plateau';
update public.utilisateurs set zone = 'Almadies / Ngor'        where btrim(zone) = 'Ngor / Almadies';

-- 3. Après : il ne doit plus rester aucun ancien nom (résultat attendu : 0)
select count(*) as anciens_noms_restants
from public.utilisateurs
where btrim(zone) in ('Plateau', 'Ngor / Almadies');

commit;
