-- SA Demonlist: owner-only, atomic level deletion
-- Run this once in the Supabase SQL Editor for the SA Demonlist project.
-- The function removes a level's completion/progress rows and closes the rank gap
-- in one transaction. Only the configured list owner can execute it.

create or replace function public.delete_level_and_reorder(p_level_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_rank integer;
begin
  if auth.uid() is distinct from '2194f047-8bc8-4e67-a59d-6738694f5884'::uuid then
    raise exception 'Only the SA Demonlist owner can delete levels';
  end if;

  perform pg_advisory_xact_lock(hashtext('public.levels.rank'));

  select rank into deleted_rank
  from public.levels
  where id = p_level_id
  for update;

  if deleted_rank is null then
    raise exception 'Level not found';
  end if;

  delete from public.completions where level_id = p_level_id;
  delete from public.level_runs where level_id = p_level_id;
  delete from public.levels where id = p_level_id;

  update public.levels
  set rank = rank - 1
  where rank > deleted_rank;
end;
$$;

revoke all on function public.delete_level_and_reorder(uuid) from public;
grant execute on function public.delete_level_and_reorder(uuid) to authenticated;
