-- SA Demonlist V10: permanent, append-only achievements.
-- Run this once in Supabase Dashboard > SQL Editor.
-- Awards are stored by player UUID and achievement ID. They are never recalculated
-- for display, and level/player changes cannot remove an existing award.

begin;

alter table public.completions
  add column if not exists rank_at_completion integer;

create table if not exists public.player_achievements (
  id bigint generated always as identity primary key,
  player_id uuid not null references public.players(id) on delete restrict,
  achievement_id text not null check (achievement_id in (
    'a1','a2','a3','a4','a5','a6','a7','a8','a9','a10',
    'a11','a12','a13','a14','a15'
  )),
  awarded_at timestamptz not null default now(),
  award_reason text not null default 'Automatically awarded',
  unique (player_id, achievement_id)
);

alter table public.player_achievements enable row level security;

drop policy if exists "Achievements are publicly readable" on public.player_achievements;
create policy "Achievements are publicly readable"
  on public.player_achievements for select to anon, authenticated using (true);

revoke all on public.player_achievements from anon, authenticated;
grant select on public.player_achievements to anon, authenticated;

create or replace function public.prevent_achievement_award_changes()
returns trigger
language plpgsql
as $$
begin
  raise exception 'Achievement awards are permanent and cannot be changed or deleted';
end;
$$;

drop trigger if exists player_achievements_immutable on public.player_achievements;
create trigger player_achievements_immutable
before update or delete on public.player_achievements
for each row execute function public.prevent_achievement_award_changes();

create or replace function public.award_achievements_for_player(p_player_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total integer := 0;
  v_top10 integer := 0;
  v_top5 integer := 0;
  v_top3 integer := 0;
  v_top1 integer := 0;
  v_verifier_top5 boolean := false;
  v_verifier_top1 boolean := false;
  v_player_name text := '';
  v_gd_username text := '';
begin
  if p_player_id is null then return; end if;

  select lower(btrim(name)), lower(btrim(coalesce(gd_username, '')))
  into v_player_name, v_gd_username
  from public.players where id = p_player_id;
  if not found then return; end if;

  select
    count(distinct level_id),
    count(distinct level_id) filter (where rank_at_completion <= 10),
    count(distinct level_id) filter (where rank_at_completion <= 5),
    count(distinct level_id) filter (where rank_at_completion <= 3),
    count(distinct level_id) filter (where rank_at_completion = 1)
  into v_total, v_top10, v_top5, v_top3, v_top1
  from public.completions
  where player_id = p_player_id;

  select
    coalesce(bool_or(coalesce(verifier_rank_at_verification, rank) <= 5), false),
    coalesce(bool_or(coalesce(verifier_rank_at_verification, rank) = 1), false)
  into v_verifier_top5, v_verifier_top1
  from public.levels
  where verifier_player_id = p_player_id;

  -- Historical restoration requested by the list owner:
  -- FwipGD verified FIJ 13 while it was #1 (therefore also Top 5).
  -- Artsonic verified a Top 1.
  if v_player_name = 'fwipgd' or v_gd_username = 'fwipgd' then
    v_verifier_top5 := true;
    v_verifier_top1 := true;
  elsif v_player_name = 'artsonic' or v_gd_username = 'artsonic' then
    v_verifier_top1 := true;
  end if;

  insert into public.player_achievements (player_id, achievement_id, award_reason)
  select p_player_id, a.achievement_id, 'Automatically awarded from verified list history'
  from (values
    ('a1', v_total >= 1),
    ('a2', v_total >= 2),
    ('a3', v_total >= 5),
    ('a4', v_total >= 1),
    ('a5', v_total >= 10),
    ('a6', v_total >= 15),
    ('a7', v_top10 >= 1),
    ('a8', v_top5 >= 1),
    ('a9', v_top10 >= 3),
    ('a10', v_verifier_top5),
    ('a11', v_top3 >= 1),
    ('a12', v_top5 >= 2),
    ('a13', v_top5 >= 5),
    ('a14', v_top1 >= 1),
    ('a15', v_verifier_top1)
  ) as a(achievement_id, should_award)
  where a.should_award
  on conflict (player_id, achievement_id) do nothing;
end;
$$;

create or replace function public.award_achievements_after_completion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- The V9 before-trigger has already captured rank_at_completion.
  -- Run this after the completion row exists so the new record is included.
  perform public.award_achievements_for_player(new.player_id);
  return new;
end;
$$;

create or replace function public.award_achievements_after_level_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.verifier_player_id is not null then
    perform public.award_achievements_for_player(new.verifier_player_id);
  end if;
  return new;
end;
$$;

create or replace function public.award_achievements_after_player_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.award_achievements_for_player(new.id);
  return new;
end;
$$;

drop trigger if exists completions_award_achievements on public.completions;
create trigger completions_award_achievements
after insert or update of player_id, level_id, rank_at_completion on public.completions
for each row execute function public.award_achievements_after_completion();

drop trigger if exists levels_award_verifier_achievements on public.levels;
create trigger levels_award_verifier_achievements
after insert or update of verifier_player_id, verifier_rank_at_verification, rank on public.levels
for each row execute function public.award_achievements_after_level_change();

drop trigger if exists players_award_name_achievements on public.players;
create trigger players_award_name_achievements
after insert or update of name on public.players
for each row execute function public.award_achievements_after_player_change();

-- Backfill every qualifying award from the data already in the database.
do $$
declare p record;
begin
  for p in select id from public.players loop
    perform public.award_achievements_for_player(p.id);
  end loop;
end;
$$;

commit;
