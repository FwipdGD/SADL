-- SA Demonlist Time Machine
-- Additive-only archive storage. This does not alter levels, players, completions,
-- ranks, points, or any existing tables.
create table if not exists public.sadl_history_snapshots (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  levels jsonb not null default '[]'::jsonb,
  players jsonb not null default '[]'::jsonb
);

alter table public.sadl_history_snapshots enable row level security;

drop policy if exists "Anyone can read SADL history snapshots" on public.sadl_history_snapshots;
create policy "Anyone can read SADL history snapshots"
  on public.sadl_history_snapshots
  for select
  to anon, authenticated
  using (true);

create or replace function public.save_sadl_history_snapshot(
  p_levels jsonb,
  p_players jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  snapshot_id uuid;
begin
  if auth.uid() is distinct from '2194f047-8bc8-4e67-a59d-6738694f5884'::uuid then
    raise exception 'Only the SADL list owner can save history snapshots';
  end if;

  if jsonb_typeof(p_levels) <> 'array' or jsonb_typeof(p_players) <> 'array' then
    raise exception 'Snapshot levels and players must be JSON arrays';
  end if;

  -- Avoid duplicate snapshots when the owner refreshes without any list changes.
  select id into snapshot_id
  from public.sadl_history_snapshots
  order by created_at desc
  limit 1;

  if snapshot_id is not null and exists (
    select 1
    from public.sadl_history_snapshots
    where id = snapshot_id
      and levels = p_levels
      and players = p_players
  ) then
    return snapshot_id;
  end if;

  insert into public.sadl_history_snapshots (levels, players)
  values (p_levels, p_players)
  returning id into snapshot_id;

  return snapshot_id;
end;
$$;

revoke all on function public.save_sadl_history_snapshot(jsonb, jsonb) from public;
grant execute on function public.save_sadl_history_snapshot(jsonb, jsonb) to authenticated;
grant select on public.sadl_history_snapshots to anon, authenticated;
