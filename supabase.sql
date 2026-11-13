-- Data4 Reporting Experience · Supabase realtime
-- Antes de ejecutar: sustituye CAMBIA_ESTE_PIN por un PIN privado del presentador.
create extension if not exists pgcrypto;

create table if not exists public.demo_sessions (
  code text primary key,
  phase text not null default 'lobby'
    check (phase in ('lobby','asis','improve','control','results')),
  presenter_pin_hash text not null,
  active boolean not null default true,
  updated_at timestamptz not null default now()
);

create table if not exists public.participants (
  id uuid primary key default gen_random_uuid(),
  session_code text not null references public.demo_sessions(code) on delete cascade,
  client_id text not null,
  role text not null check (role in ('gestor','area','graduate','tecnico')),
  joined_at timestamptz not null default now(),
  unique(session_code, client_id)
);

create table if not exists public.responses (
  id uuid primary key default gen_random_uuid(),
  session_code text not null references public.demo_sessions(code) on delete cascade,
  client_id text not null,
  role text not null check (role in ('gestor','area','graduate','tecnico')),
  phase text not null check (phase in ('asis','improve','control')),
  answer text not null,
  created_at timestamptz not null default now()
);

insert into public.demo_sessions(code,phase,presenter_pin_hash,active)
values ('D4DEMO','lobby',crypt('CAMBIA_ESTE_PIN',gen_salt('bf')),true)
on conflict (code) do nothing;

alter table public.demo_sessions enable row level security;
alter table public.participants enable row level security;
alter table public.responses enable row level security;

grant select on public.demo_sessions to anon, authenticated;
grant select, insert, update on public.participants to anon, authenticated;
grant select, insert on public.responses to anon, authenticated;

drop policy if exists "read active sessions" on public.demo_sessions;
create policy "read active sessions" on public.demo_sessions
for select to anon, authenticated using (active = true);

drop policy if exists "participants read" on public.participants;
create policy "participants read" on public.participants
for select to anon, authenticated using (true);

drop policy if exists "participants insert" on public.participants;
create policy "participants insert" on public.participants
for insert to anon, authenticated with check (true);

drop policy if exists "participants update" on public.participants;
create policy "participants update" on public.participants
for update to anon, authenticated using (true) with check (true);

drop policy if exists "responses read" on public.responses;
create policy "responses read" on public.responses
for select to anon, authenticated using (true);

drop policy if exists "responses insert" on public.responses;
create policy "responses insert" on public.responses
for insert to anon, authenticated with check (true);

create or replace function public.set_demo_phase(
  p_code text,
  p_pin text,
  p_phase text
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_phase not in ('lobby','asis','improve','control','results') then
    raise exception 'Invalid phase';
  end if;

  update public.demo_sessions
     set phase = p_phase, updated_at = now()
   where code = p_code
     and active = true
     and presenter_pin_hash = crypt(p_pin, presenter_pin_hash);

  return found;
end;
$$;

revoke all on function public.set_demo_phase(text,text,text) from public;
grant execute on function public.set_demo_phase(text,text,text) to anon, authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime'
      and schemaname='public'
      and tablename='demo_sessions'
  ) then
    alter publication supabase_realtime add table public.demo_sessions;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime'
      and schemaname='public'
      and tablename='participants'
  ) then
    alter publication supabase_realtime add table public.participants;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime'
      and schemaname='public'
      and tablename='responses'
  ) then
    alter publication supabase_realtime add table public.responses;
  end if;
end $$;
