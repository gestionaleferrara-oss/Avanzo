-- Avanzo: database su Supabase.
-- Da eseguire una volta in Supabase › SQL Editor › New query › Run.

-- Dati di ogni utente: un documento per persona.
create table if not exists public.stati (
  user_id      uuid primary key references auth.users (id) on delete cascade,
  dati         jsonb       not null,
  versione     bigint      not null default 1,
  aggiornato_il timestamptz not null default now()
);

alter table public.stati enable row level security;

-- Ognuno vede e modifica solo i propri dati.
drop policy if exists "stati: leggo i miei" on public.stati;
create policy "stati: leggo i miei" on public.stati
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "stati: creo i miei" on public.stati;
create policy "stati: creo i miei" on public.stati
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "stati: aggiorno i miei" on public.stati;
create policy "stati: aggiorno i miei" on public.stati
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop policy if exists "stati: cancello i miei" on public.stati;
create policy "stati: cancello i miei" on public.stati
  for delete to authenticated using ((select auth.uid()) = user_id);

-- Piano di ogni utente (Gratis, Plus, a vita).
-- L'utente può solo leggerlo: lo scrive il server quando Stripe conferma un pagamento.
create table if not exists public.piani (
  user_id     uuid primary key references auth.users (id) on delete cascade,
  piano       text        not null default 'gratis' check (piano in ('gratis', 'plus_mese', 'plus_anno', 'plus_vita')),
  valido_fino timestamptz,
  stripe_customer text,
  aggiornato_il timestamptz not null default now()
);

alter table public.piani enable row level security;

drop policy if exists "piani: leggo il mio" on public.piani;
create policy "piani: leggo il mio" on public.piani
  for select to authenticated using ((select auth.uid()) = user_id);
