-- Avanzo: acquisti da Stripe e attivazione automatica di Plus.
-- Da eseguire una volta in Supabase › SQL Editor (dopo schema.sql).

-- Ogni pagamento confermato da Stripe. Lo scrive solo il server (nessuna policy per gli utenti).
create table if not exists public.acquisti (
  id                    bigserial primary key,
  email                 text        not null,
  piano                 text        not null check (piano in ('plus_mese', 'plus_anno', 'plus_vita')),
  valido_fino           timestamptz,
  stripe_session        text unique,
  stripe_payment_intent text,
  stripe_customer       text,
  importo               integer,
  valuta                text,
  rimborsato            boolean     not null default false,
  creato_il             timestamptz not null default now()
);
create index if not exists acquisti_email on public.acquisti (lower(email));
create index if not exists acquisti_pi on public.acquisti (stripe_payment_intent);
alter table public.acquisti enable row level security;

-- Ricalcola il piano di chi ha questa email (se ha già un account).
create or replace function public.aggiorna_piano_email(p_email text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  u uuid;
  a record;
begin
  select id into u from auth.users where lower(email) = lower(p_email) limit 1;
  if u is null then return; end if;

  select * into a from public.acquisti
   where lower(email) = lower(p_email) and not rimborsato
     and (valido_fino is null or valido_fino > now())
   order by (piano = 'plus_vita') desc, valido_fino desc nulls first
   limit 1;

  if not found then
    insert into public.piani (user_id, piano) values (u, 'gratis')
    on conflict (user_id) do update set piano = 'gratis', valido_fino = null, aggiornato_il = now();
  else
    insert into public.piani (user_id, piano, valido_fino, stripe_customer)
    values (u, a.piano, a.valido_fino, a.stripe_customer)
    on conflict (user_id) do update
      set piano = excluded.piano, valido_fino = excluded.valido_fino,
          stripe_customer = excluded.stripe_customer, aggiornato_il = now();
  end if;
end $$;
revoke all on function public.aggiorna_piano_email(text) from public, anon, authenticated;

-- Quando arriva (o cambia) un acquisto.
create or replace function public.dopo_acquisto()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform public.aggiorna_piano_email(new.email);
  return new;
end $$;
drop trigger if exists acquisti_aggiorna_piano on public.acquisti;
create trigger acquisti_aggiorna_piano after insert or update on public.acquisti
  for each row execute function public.dopo_acquisto();

-- Quando qualcuno crea l'account dopo aver già pagato.
create or replace function public.dopo_nuovo_utente()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.acquisti where lower(email) = lower(new.email)) then
    perform public.aggiorna_piano_email(new.email);
  end if;
  return new;
end $$;
drop trigger if exists utenti_piano_da_acquisti on auth.users;
create trigger utenti_piano_da_acquisti after insert on auth.users
  for each row execute function public.dopo_nuovo_utente();
