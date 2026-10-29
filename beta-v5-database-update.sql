-- SADL Beta V5 database update
-- Run this in Supabase SQL Editor before testing the new Top 1 achievements.
-- Existing completion records are backfilled with each level's CURRENT rank;
-- Supabase cannot reconstruct historical ranks that were never saved.

alter table public.levels
  add column if not exists verifier_player_id uuid references public.players(id) on delete set null,
  add column if not exists verifier_rank_at_verification integer;

alter table public.completions
  add column if not exists rank_at_completion integer;

update public.completions c
set rank_at_completion = l.rank
from public.levels l
where c.level_id = l.id
  and c.rank_at_completion is null;

create or replace function public.sadl_capture_completion_rank()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if new.rank_at_completion is null then
    select rank into new.rank_at_completion
    from public.levels
    where id = new.level_id;
  end if;
  return new;
end;
$$;

drop trigger if exists sadl_capture_completion_rank_before_insert on public.completions;
create trigger sadl_capture_completion_rank_before_insert
before insert on public.completions
for each row execute function public.sadl_capture_completion_rank();

-- Keep existing table permissions/RLS in place. This migration only adds fields
-- and a trigger; it does not grant new access or change existing policies.
