-- SA Demonlist V9: preserve the list position a level had when it was completed.
-- Run once in Supabase SQL Editor before using the updated V8 beta.
alter table public.completions
  add column if not exists rank_at_completion integer;

-- Backfill existing records with the level's current rank as a safe fallback.
-- Historical ranks cannot be reconstructed unless they were previously recorded.
update public.completions c
set rank_at_completion = l.rank
from public.levels l
where c.level_id = l.id
  and c.rank_at_completion is null;

create or replace function public.capture_completion_rank()
returns trigger
language plpgsql
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

drop trigger if exists completions_capture_rank on public.completions;
create trigger completions_capture_rank
before insert or update of level_id on public.completions
for each row
execute function public.capture_completion_rank();
