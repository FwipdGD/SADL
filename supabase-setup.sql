-- SA Demonlist shared database setup
-- Run this entire file in Supabase Dashboard > SQL Editor > New query.

create extension if not exists pgcrypto;

create table if not exists public.members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.levels (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  creator text not null default '',
  difficulty text not null default 'Extreme Demon',
  rank integer not null unique,
  thumbnail_url text not null default '',
  showcase_url text not null default '',
  notes text not null default '',
  created_at timestamptz not null default now(),
  constraint levels_rank_positive check (rank > 0)
);

create table if not exists public.players (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  gd_username text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.completions (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  level_id uuid not null references public.levels(id) on delete cascade,
  proof_url text not null default '',
  beaten_on date,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (player_id, level_id)
);

alter table public.members enable row level security;
alter table public.levels enable row level security;
alter table public.players enable row level security;
alter table public.completions enable row level security;

drop policy if exists "Anyone can read member display names" on public.members;
create policy "Anyone can read member display names" on public.members
for select to anon, authenticated using (true);

drop policy if exists "Anyone can read levels" on public.levels;
create policy "Anyone can read levels" on public.levels
for select to anon, authenticated using (true);

drop policy if exists "Anyone can read players" on public.players;
create policy "Anyone can read players" on public.players
for select to anon, authenticated using (true);

drop policy if exists "Anyone can read completions" on public.completions;
create policy "Anyone can read completions" on public.completions
for select to anon, authenticated using (true);

drop policy if exists "Members can insert levels" on public.levels;
create policy "Members can insert levels" on public.levels
for insert to authenticated with check (
  exists (select 1 from public.members m where m.user_id = auth.uid())
);

drop policy if exists "Members can update levels" on public.levels;
create policy "Members can update levels" on public.levels
for update to authenticated using (
  exists (select 1 from public.members m where m.user_id = auth.uid())
) with check (
  exists (select 1 from public.members m where m.user_id = auth.uid())
);

drop policy if exists "Members can delete levels" on public.levels;
create policy "Members can delete levels" on public.levels
for delete to authenticated using (
  exists (select 1 from public.members m where m.user_id = auth.uid())
);

drop policy if exists "Members can insert players" on public.players;
create policy "Members can insert players" on public.players
for insert to authenticated with check (
  exists (select 1 from public.members m where m.user_id = auth.uid())
);

drop policy if exists "Members can update players" on public.players;
create policy "Members can update players" on public.players
for update to authenticated using (
  exists (select 1 from public.members m where m.user_id = auth.uid())
) with check (
  exists (select 1 from public.members m where m.user_id = auth.uid())
);

drop policy if exists "Members can delete players" on public.players;
create policy "Members can delete players" on public.players
for delete to authenticated using (
  exists (select 1 from public.members m where m.user_id = auth.uid())
);

drop policy if exists "Members can insert completions" on public.completions;
create policy "Members can insert completions" on public.completions
for insert to authenticated with check (
  exists (select 1 from public.members m where m.user_id = auth.uid())
);

drop policy if exists "Members can update completions" on public.completions;
create policy "Members can update completions" on public.completions
for update to authenticated using (
  exists (select 1 from public.members m where m.user_id = auth.uid())
) with check (
  exists (select 1 from public.members m where m.user_id = auth.uid())
);

drop policy if exists "Members can delete completions" on public.completions;
create policy "Members can delete completions" on public.completions
for delete to authenticated using (
  exists (select 1 from public.members m where m.user_id = auth.uid())
);

create or replace function public.move_level(p_level_id uuid, p_target_rank integer)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_rank integer;
  total integer;
begin
  if not exists (select 1 from public.members where user_id = auth.uid()) then
    raise exception 'Only approved SA Demonlist members can edit placements';
  end if;

  select rank into current_rank from public.levels where id = p_level_id;
  if current_rank is null then raise exception 'Level not found'; end if;
  select count(*) into total from public.levels;
  p_target_rank := greatest(1, least(coalesce(p_target_rank, total), total));

  -- Move all ranks out of the constrained range first, then rebuild them without collisions.
  update public.levels set rank = rank + 1000000;
  with original as (
    select id, rank - 1000000 as old_rank
    from public.levels
  ), ordered as (
    select id, row_number() over (
      order by case
        when id = p_level_id then p_target_rank
        when current_rank < p_target_rank and old_rank > current_rank and old_rank <= p_target_rank then old_rank - 1
        when current_rank > p_target_rank and old_rank >= p_target_rank and old_rank < current_rank then old_rank + 1
        else old_rank
      end
    )::integer as new_rank
    from original
  )
  update public.levels l set rank = o.new_rank from ordered o where l.id = o.id;
end;
$$;

create or replace function public.delete_level_and_reorder(p_level_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from public.members where user_id = auth.uid()) then
    raise exception 'Only approved SA Demonlist members can edit placements';
  end if;
  delete from public.levels where id = p_level_id;
  update public.levels set rank = rank + 1000000;
  with ordered as (
    select id, row_number() over (order by rank)::integer as new_rank
    from public.levels
  )
  update public.levels l set rank = o.new_rank from ordered o where l.id = o.id;
end;
$$;

revoke all on function public.move_level(uuid, integer) from public;
grant execute on function public.move_level(uuid, integer) to authenticated;
revoke all on function public.delete_level_and_reorder(uuid) from public;
grant execute on function public.delete_level_and_reorder(uuid) to authenticated;

-- IMPORTANT:
-- After signing in once with each approved member email, find that user in
-- Supabase Dashboard > Authentication > Users and copy their UUID.
-- Then run a statement like:
-- insert into public.members (user_id, display_name)
-- values ('PASTE-USER-UUID-HERE', 'Player display name');
-- Repeat only for people allowed to edit. Do not share the service-role key.
