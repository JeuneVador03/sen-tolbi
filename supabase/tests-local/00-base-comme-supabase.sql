-- Postgres local seulement : reproduit ce que Supabase fournit (rôles, auth.uid())
-- et les tables telles qu'elles sont en base réelle le 8/11/2026 (lues en lecture seule).
create extension if not exists "uuid-ossp";
do $$ begin
  create role anon nologin; exception when duplicate_object then null; end $$;
do $$ begin
  create role authenticated nologin; exception when duplicate_object then null; end $$;
do $$ begin
  create role service_role nologin bypassrls; exception when duplicate_object then null; end $$;
create schema auth;
create table auth.users (id uuid primary key, email text);
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
grant usage on schema auth to anon, authenticated;
grant execute on function auth.uid() to anon, authenticated;

create table public.utilisateurs (
  id uuid primary key default uuid_generate_v4(), prenom text not null, nom text not null,
  telephone text not null unique, email text, mot_de_passe text not null,
  type text not null check (type = any (array['vendeur','acheteur'])),
  zone text, type_production text, type_acheteur text, moyen_paiement text,
  created_at timestamp default now());
create table public.produits (
  id uuid primary key default uuid_generate_v4(),
  vendeur_id uuid references public.utilisateurs(id) on delete cascade,
  nom text not null, categorie text not null, prix integer not null, quantite integer not null,
  unite text not null, description text, created_at timestamp default now());
create table public.commandes (
  id uuid primary key default uuid_generate_v4(),
  acheteur_id uuid references public.utilisateurs(id), vendeur_id uuid references public.utilisateurs(id),
  produit_id uuid references public.produits(id), quantite integer not null,
  montant_total integer not null, commission integer not null,
  statut text default 'en_attente', created_at timestamp default now());
grant usage on schema public to anon, authenticated;
grant all on public.utilisateurs, public.produits, public.commandes to anon, authenticated, service_role;
