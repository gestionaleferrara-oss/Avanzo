-- Avanzo: misura delle visite (senza cookie), posti fondatore, lista d'attesa Famiglia, provenienza degli acquisti.
-- Da eseguire una volta in Supabase › SQL Editor (dopo acquisti.sql).

-- Eventi anonimi: nessun dato personale, solo cosa è successo, su quale pagina e da quale creator (ref).
create table if not exists public.eventi (
  id        bigserial primary key,
  tipo      text not null check (tipo in ('visita', 'demo', 'clic_fondatore', 'lista_famiglia', 'accesso')),
  pagina    text check (length(pagina) <= 40),
  ref       text check (length(ref) <= 40),
  creato_il timestamptz not null default now()
);
alter table public.eventi enable row level security;
drop policy if exists "eventi: chiunque registra" on public.eventi;
create policy "eventi: chiunque registra" on public.eventi for insert to anon, authenticated with check (true);

-- Lista d'attesa (per ora: Avanzo Famiglia). Chiunque si iscrive, nessuno può leggere dal sito.
create table if not exists public.lista_attesa (
  id        bigserial primary key,
  email     text not null check (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' and length(email) <= 200),
  prodotto  text not null default 'famiglia' check (prodotto in ('famiglia')),
  ref       text check (length(ref) <= 40),
  creato_il timestamptz not null default now(),
  unique (email, prodotto)
);
alter table public.lista_attesa enable row level security;
drop policy if exists "lista: chiunque si iscrive" on public.lista_attesa;
create policy "lista: chiunque si iscrive" on public.lista_attesa for insert to anon, authenticated with check (true);

-- Da quale creator arriva ogni acquisto.
alter table public.acquisti add column if not exists ref text;

-- Posti fondatore rimasti (numero pubblico, nessun dato personale).
create or replace function public.posti_fondatore()
returns integer language sql stable security definer set search_path = '' as $$
  select greatest(0, 300 - (select count(*) from public.acquisti where piano = 'plus_vita' and not rimborsato))::int;
$$;
revoke all on function public.posti_fondatore() from public;
grant execute on function public.posti_fondatore() to anon, authenticated;

-- Iscritti alla lista Famiglia (solo il numero, per mostrarlo sul sito).
create or replace function public.iscritti_famiglia()
returns integer language sql stable security definer set search_path = '' as $$
  select count(*)::int from public.lista_attesa where prodotto = 'famiglia';
$$;
revoke all on function public.iscritti_famiglia() from public;
grant execute on function public.iscritti_famiglia() to anon, authenticated;

-- Riepilogo per te (si legge solo dal pannello di Supabase): ultimi 30 giorni, per creator.
create or replace view public.riepilogo_crescita with (security_invoker = true) as
with e as (
  select coalesce(ref, '(diretto)') as p, tipo from public.eventi where creato_il > now() - interval '30 days'
), v as (
  select p,
         count(*) filter (where tipo = 'visita')         as visite,
         count(*) filter (where tipo = 'demo')           as demo_aperte,
         count(*) filter (where tipo = 'clic_fondatore') as clic_fondatore,
         count(*) filter (where tipo = 'lista_famiglia') as iscritti_famiglia
  from e group by p
), a as (
  select coalesce(ref, '(diretto)') as p, count(*) as acquisti
  from public.acquisti where not rimborsato and creato_il > now() - interval '30 days' group by 1
)
select coalesce(v.p, a.p) as provenienza,
       coalesce(v.visite, 0) as visite, coalesce(v.demo_aperte, 0) as demo_aperte,
       coalesce(v.clic_fondatore, 0) as clic_fondatore, coalesce(v.iscritti_famiglia, 0) as iscritti_famiglia,
       coalesce(a.acquisti, 0) as acquisti
from v full join a on a.p = v.p
order by visite desc;
revoke all on public.riepilogo_crescita from anon, authenticated;
