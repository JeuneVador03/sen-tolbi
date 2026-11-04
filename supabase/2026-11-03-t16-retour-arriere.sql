-- =====================================================================
-- Sen Tolbi · Tâche 16 · RETOUR EN ARRIÈRE
-- Supprime la fonction prenoms_de_mes_acheteurs(). Aucune donnée n'est
-- touchée. L'espace vendeur doit alors cesser d'appeler
-- rpc('prenoms_de_mes_acheteurs') (sinon il affiche une erreur).
-- =====================================================================
begin;
drop function if exists public.prenoms_de_mes_acheteurs();
commit;
