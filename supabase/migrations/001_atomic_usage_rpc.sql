-- ============================================================
-- Atomic rate-limit check-and-increment functions
-- Prevents race conditions when multiple requests arrive simultaneously
-- Run in: Supabase Dashboard → SQL Editor → New query
-- ============================================================

-- Atomically check scan limit and increment if under limit.
-- Returns the NEW scan_count after increment, or -1 if limit was reached.
create or replace function public.increment_scan_if_allowed(
  p_user_id uuid,
  p_date date,
  p_limit int
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new_count int;
begin
  -- Insert row if missing, then atomically increment only if under limit
  insert into public.usage (user_id, date, scan_count, chat_count)
  values (p_user_id, p_date, 1, 0)
  on conflict (user_id, date) do update
    set scan_count = usage.scan_count + 1
    where usage.scan_count < p_limit
  returning scan_count into v_new_count;

  -- If no row was affected (limit already reached), return -1
  if v_new_count is null then
    return -1;
  end if;

  return v_new_count;
end;
$$;

-- Atomically check chat limit and increment if under limit.
-- Returns the NEW chat_count after increment, or -1 if limit was reached.
create or replace function public.increment_chat_if_allowed(
  p_user_id uuid,
  p_date date,
  p_limit int
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new_count int;
begin
  insert into public.usage (user_id, date, scan_count, chat_count)
  values (p_user_id, p_date, 0, 1)
  on conflict (user_id, date) do update
    set chat_count = usage.chat_count + 1
    where usage.chat_count < p_limit
  returning chat_count into v_new_count;

  if v_new_count is null then
    return -1;
  end if;

  return v_new_count;
end;
$$;
