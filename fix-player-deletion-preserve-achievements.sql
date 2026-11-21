-- SADL: allow owner-only player removal without destroying permanent achievements.
-- Run once in Supabase Dashboard > SQL Editor.
-- The player's historical awards remain in player_achievements with a name snapshot.

begin;

alter table public.player_achievements
  add column if not exists player_name_snapshot text,
  add column if not exists gd_username_snapshot text;

alter table public.player_achievements
  alter column player_id drop not null;

alter table public.player_achievements
  drop constraint if exists player_achievements_player_id_fkey;

alter table public.player_achievements
  add constraint player_achievements_player_id_fkey
  foreign key (player_id) references public.players(id) on delete set null;

-- Keep achievement identity and award details immutable. The only permitted
-- update is detaching an award from a deleted player while recording their name.
create or replace function public.prevent_achievement_award_changes()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE'
     and old.player_id is not null
     and new.player_id is null
     and new.player_name_snapshot is not null
     and new.gd_username_snapshot is not null
     and (to_jsonb(new) - 'player_id' - 'player_name_snapshot' - 'gd_username_snapshot')
         = (to_jsonb(old) - 'player_id' - 'player_name_snapshot' - 'gd_username_snapshot')
  then
    return new;
  end if;

  raise exception 'Achievement awards are permanent and cannot be changed or deleted';
end;
$$;

create or replace function public.delete_player_and_preserve_achievements(p_player_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
  v_gd_username text;
begin
  if auth.uid() is distinct from '2194f047-8bc8-4e67-a59d-6738694f5884'::uuid then
    raise exception 'Only the SA Demonlist owner can delete players';
  end if;

  select name, coalesce(gd_username, '')
    into v_name, v_gd_username
  from public.players
  where id = p_player_id
  for update;

  if not found then
    raise exception 'Player not found';
  end if;

  update public.player_achievements
  set player_name_snapshot = v_name,
      gd_username_snapshot = v_gd_username,
      player_id = null
  where player_id = p_player_id;

  delete from public.players where id = p_player_id;
end;
$$;

revoke all on function public.delete_player_and_preserve_achievements(uuid) from public;
grant execute on function public.delete_player_and_preserve_achievements(uuid) to authenticated;

commit;
