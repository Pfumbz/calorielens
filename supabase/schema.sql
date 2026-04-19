-- ============================================================
-- CalorieLens — Supabase Database Schema
-- Run this in: Supabase Dashboard → SQL Editor → New query
-- ============================================================

-- ── profiles ──────────────────────────────────────────────────
-- One row per user. Links to Supabase Auth (auth.users).
create table if not exists public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  email         text,
  name          text default '',
  age           int default 0,
  weight_kg     decimal default 0,
  height_cm     int default 0,
  sex           text default 'm',
  activity      decimal default 1.55,
  calorie_goal  int default 2000,
  is_premium    boolean default false,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

-- Auto-create profile on sign-up
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ── usage ─────────────────────────────────────────────────────
-- Tracks daily scan and chat usage per user.
create table if not exists public.usage (
  user_id    uuid references public.profiles(id) on delete cascade,
  date       date not null,
  scan_count int default 0,
  chat_count int default 0,
  primary key (user_id, date)
);

-- ── diary_entries ─────────────────────────────────────────────
-- Cloud-synced meal diary entries.
create table if not exists public.diary_entries (
  id          bigserial primary key,
  user_id     uuid references public.profiles(id) on delete cascade,
  date        date not null,
  time        text not null,
  meal_name   text not null,
  calories    int default 0,
  protein_g   int default 0,
  carbs_g     int default 0,
  fat_g       int default 0,
  fiber_g     int default 0,
  created_at  timestamptz default now()
);

-- ── Row Level Security (RLS) ──────────────────────────────────
-- Users can only see and modify their own data.

alter table public.profiles enable row level security;
alter table public.usage enable row level security;
alter table public.diary_entries enable row level security;

-- profiles
create policy "Users can view their own profile"
  on public.profiles for select using (auth.uid() = id);

create policy "Users can update their own profile"
  on public.profiles for update using (auth.uid() = id);

create policy "Users can insert their own profile"
  on public.profiles for insert with check (auth.uid() = id);

-- usage
create policy "Users can view their own usage"
  on public.usage for select using (auth.uid() = user_id);

create policy "Users can upsert their own usage"
  on public.usage for all using (auth.uid() = user_id);

-- diary_entries
create policy "Users can view their own diary"
  on public.diary_entries for select using (auth.uid() = user_id);

create policy "Users can insert into their own diary"
  on public.diary_entries for insert with check (auth.uid() = user_id);

create policy "Users can delete their own diary entries"
  on public.diary_entries for delete using (auth.uid() = user_id);

-- Edge Functions need to read profiles and usage via service_role key,
-- so no additional policy needed for Edge Functions (they use service_role).

-- ── Indexes ────────────────────────────────────────────────────
create index if not exists idx_diary_user_date on public.diary_entries(user_id, date);
create index if not exists idx_usage_user_date on public.usage(user_id, date);
