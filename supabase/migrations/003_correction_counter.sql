-- ============================================================
-- 003 — Separate daily allowance for corrections / re-analyses
--
-- The H1 fix metered corrections against the scan counter, which meant a
-- re-analyse consumed a user's scan quota (bad UX, especially for the 3-scan
-- guest tier) and could trip the scan limit. This gives corrections their own
-- counter + cap: corrections no longer touch scan quota, but are still bounded
-- so the "send correction_hint on every request" exploit stays closed.
-- ============================================================

alter table public.usage
  add column if not exists correction_count int default 0;

create or replace function public.increment_correction_if_allowed(
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
  insert into public.usage (user_id, date, scan_count, chat_count, correction_count)
  values (p_user_id, p_date, 0, 0, 1)
  on conflict (user_id, date) do update
    set correction_count = usage.correction_count + 1
    where usage.correction_count < p_limit
  returning correction_count into v_new_count;

  if v_new_count is null then
    return -1;
  end if;

  return v_new_count;
end;
$$;
