-- Data4 Reporting Experience · Supabase MVP
-- No almacena nombres, emails ni otros datos personales.

create extension if not exists pgcrypto;

create table if not exists public.demo_sessions (
  code text primary key,
  phase text not null default 'lobby'
    check (phase in ('lobby','asis','improve','control','results')),
  presenter_pin text not null default '2468',
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

insert into public.demo_sessions(code,phase,presenter_pin,active)
values ('D4DEMO','lobby','2468',true)
on conflict (code) do nothing;

alter table public.demo_sessions enable row level security;
alter table public.participants enable row level security;
alter table public.responses enable row level security;

-- Políticas deliberadamente simples para una demo pública sin PII.
drop policy if exists "read active sessions" on public.demo_sessions;
create policy "read active sessions" on public.demo_sessions for select using (active = true);

drop policy if exists "update session phase" on public.demo_sessions;
create policy "update session phase" on public.demo_sessions for update using (active = true) with check (active = true);

drop policy if exists "participants read" on public.participants;
create policy "participants read" on public.participants for select using (true);
drop policy if exists "participants insert" on public.participants;
create policy "participants insert" on public.participants for insert with check (true);
drop policy if exists "participants update" on public.participants;
create policy "participants update" on public.participants for update using (true) with check (true);

drop policy if exists "responses read" on public.responses;
create policy "responses read" on public.responses for select using (true);
drop policy if exists "responses insert" on public.responses;
create policy "responses insert" on public.responses for insert with check (true);

alter publication supabase_realtime add table public.demo_sessions;
alter publication supabase_realtime add table public.participants;
alter publication supabase_realtime add table public.responses;
