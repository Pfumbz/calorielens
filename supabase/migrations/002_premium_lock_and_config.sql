-- ============================================================
-- 002 — Lock premium entitlement server-side (C1) + remote app config
--
-- C1 fix: `profiles.is_premium` was writable by the user via RLS, and the
-- Edge Functions trust it to decide tier. This migration makes entitlement
-- columns writable ONLY by the service role (i.e. the verify-purchase Edge
-- Function). Any attempt by an authenticated/anon client to set them is
-- silently reverted. Existing premium rows are preserved.
-- ============================================================

-- 1. Entitlement bookkeeping columns ---------------------------------------
alter table public.profiles
  add column if not exists pro_purchase_token text,
  add column if not exists pro_verified      boolean not null default false,
  add column if not exists pro_expires_at    timestamptz,
  add column if not exists pro_updated_at     timestamptz;

-- A single Play purchase token must not grant Pro on multiple accounts.
create unique index if not exists uq_profiles_pro_token
  on public.profiles (pro_purchase_token)
  where pro_purchase_token is not null;

-- 2. Guard trigger ----------------------------------------------------------
-- SECURITY INVOKER (default) so current_user reflects the PostgREST-set role
-- (service_role for Edge Functions using the service key; authenticated/anon
-- for client requests). Do NOT make this SECURITY DEFINER — that would make
-- current_user the function owner and defeat the check.
create or replace function public.guard_premium_columns()
returns trigger
language plpgsql
set search_path = ''  -- function references no unqualified objects
as $$
declare
  is_privileged boolean := current_user in ('service_role', 'postgres', 'supabase_admin');
begin
  if is_privileged then
    return new;
  end if;

  if tg_op = 'INSERT' then
    -- Clients may never self-provision entitlement on insert.
    new.is_premium        := false;
    new.pro_purchase_token := null;
    new.pro_verified      := false;
    new.pro_expires_at    := null;
    new.pro_updated_at     := null;
    return new;
  end if;

  -- UPDATE: preserve the existing privileged values regardless of input.
  new.is_premium        := old.is_premium;
  new.pro_purchase_token := old.pro_purchase_token;
  new.pro_verified      := old.pro_verified;
  new.pro_expires_at    := old.pro_expires_at;
  new.pro_updated_at     := old.pro_updated_at;
  return new;
end;
$$;

drop trigger if exists trg_guard_premium_columns on public.profiles;
create trigger trg_guard_premium_columns
  before insert or update on public.profiles
  for each row execute function public.guard_premium_columns();

-- 3. Defence-in-depth: add WITH CHECK to the existing update policy ---------
drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- 4. Remote app config (forced-update minimum build, etc.) ------------------
create table if not exists public.app_config (
  key   text primary key,
  value text not null
);

alter table public.app_config enable row level security;

drop policy if exists "App config is readable" on public.app_config;
create policy "App config is readable"
  on public.app_config for select
  using (true);  -- non-sensitive (just a min build number); no write policy = clients cannot modify

-- Seed permissive: forces no one until you raise this to the new build number
-- AFTER the new app version (build 13) is live on the Play Store.
insert into public.app_config (key, value)
values ('min_supported_build', '12')
on conflict (key) do nothing;
