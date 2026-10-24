-- Fix level reordering for SA Demonlist
-- Run this entire script in Supabase SQL Editor.
-- It replaces move_level with a version that always scopes updates with WHERE.

create or replace function public.move_level(
  p_level_id uuid,
  p_target_rank integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current_rank integer;
  v_target_rank integer;
  v_max_rank integer;
  v_offset integer := 1000000;
  v_temp_rank integer;
begin
  -- Only FWIPGD's account can reorder levels.
  if auth.uid() is distinct from '2194f047-8bc8-4e67-a59d-6738694f5884'::uuid then
    raise exception 'Only FWIPGD can reorder levels.';
  end if;

  select rank into v_current_rank
  from public.levels
  where id = p_level_id
  for update;

  if not found then
    raise exception 'Level not found.';
  end if;

  select coalesce(max(rank), 0) into v_max_rank from public.levels;
  v_target_rank := greatest(1, least(coalesce(p_target_rank, 1), v_max_rank));

  if v_current_rank = v_target_rank then
    return;
  end if;

  -- Park the selected level at a temporary rank outside the live range.
  v_temp_rank := v_max_rank + (2 * v_offset);
  update public.levels
  set rank = v_temp_rank
  where id = p_level_id;

  if v_target_rank < v_current_rank then
    -- Move affected rows out of the way, then return them one place lower.
    update public.levels
    set rank = rank + v_offset
    where rank >= v_target_rank
      and rank < v_current_rank
      and id <> p_level_id;

    update public.levels
    set rank = rank - v_offset + 1
    where rank >= v_target_rank + v_offset
      and rank < v_current_rank + v_offset
      and id <> p_level_id;
  else
    -- Move affected rows out of the way, then return them one place higher.
    update public.levels
    set rank = rank + v_offset
    where rank > v_current_rank
      and rank <= v_target_rank
      and id <> p_level_id;

    update public.levels
    set rank = rank - v_offset - 1
    where rank > v_current_rank + v_offset
      and rank <= v_target_rank + v_offset
      and id <> p_level_id;
  end if;

  update public.levels
  set rank = v_target_rank
  where id = p_level_id;
end;
$$;

revoke all on function public.move_level(uuid, integer) from public;
grant execute on function public.move_level(uuid, integer) to authenticated;
