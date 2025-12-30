-- Enable pgcrypto for gen_random_uuid if needed
create extension if not exists pgcrypto;

create table if not exists public.sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  started_at timestamptz not null default now(),
  duration_s int not null default 0,
  presence_score real not null default 0,
  aff_count int not null default 3,
  emotion_tag text,
  completed boolean not null default true
);

alter table public.sessions enable row level security;

create policy "users can view own sessions"
on public.sessions for select
to authenticated
using (auth.uid() = user_id);

create policy "users can insert own sessions"
on public.sessions for insert
to authenticated
with check (auth.uid() = user_id);

create policy "users can update own sessions"
on public.sessions for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
