-- Avanzo: codici beta (Plus gratis ai primi tester). Da eseguire dopo crescita.sql.
create table if not exists public.codici (
  codice    text primary key,
  piano     text not null default 'plus_vita' check (piano in ('plus_mese', 'plus_anno', 'plus_vita')),
  usi_max   integer not null default 50,
  usi       integer not null default 0,
  attivo    boolean not null default true,
  creato_il timestamptz not null default now()
);
alter table public.codici enable row level security;

-- Chi ha già Plus, o ha già usato un codice, non consuma un posto.
create or replace function public.riscatta_codice(p_codice text)
returns text language plpgsql security definer set search_path = '' as $$
declare
  u uuid := auth.uid();
  e text;
  c record;
begin
  if u is null then return 'accedi'; end if;
  select email into e from auth.users where id = u;
  select * into c from public.codici where codice = upper(trim(p_codice)) for update;
  if not found or not c.attivo then return 'non_valido'; end if;
  if exists (select 1 from public.piani where user_id = u and piano <> 'gratis') then return 'gia_plus'; end if;
  if c.usi >= c.usi_max then return 'esaurito'; end if;
  insert into public.acquisti (email, piano, stripe_session, importo, valuta, ref)
  values (lower(e), c.piano, 'codice:' || c.codice || ':' || u, 0, 'eur', lower(c.codice))
  on conflict (stripe_session) do nothing;
  update public.codici set usi = usi + 1 where codice = c.codice;
  return 'ok';
end $$;
revoke all on function public.riscatta_codice(text) from public, anon;
grant execute on function public.riscatta_codice(text) to authenticated;

-- Posti rimasti per un codice (numero pubblico).
create or replace function public.posti_codice(p_codice text)
returns integer language sql stable security definer set search_path = '' as $$
  select coalesce((select greatest(0, usi_max - usi) from public.codici where codice = upper(trim(p_codice)) and attivo), 0)::int;
$$;
revoke all on function public.posti_codice(text) from public;
grant execute on function public.posti_codice(text) to anon, authenticated;

-- I posti fondatore contano solo gli acquisti pagati.
create or replace function public.posti_fondatore()
returns integer language sql stable security definer set search_path = '' as $$
  select greatest(0, 300 - (select count(*) from public.acquisti where piano = 'plus_vita' and not rimborsato and coalesce(importo, 0) > 0))::int;
$$;

insert into public.codici (codice, piano, usi_max) values ('BETA50', 'plus_vita', 50) on conflict (codice) do nothing;
