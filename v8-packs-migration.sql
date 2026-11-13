-- SA Demonlist V8: community level packs
create table if not exists public.level_packs (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 80),
  category text not null default '' check (char_length(category) <= 60),
  description text not null default '' check (char_length(description) <= 240),
  level_names text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.level_packs enable row level security;
drop policy if exists "Packs are publicly readable" on public.level_packs;
create policy "Packs are publicly readable" on public.level_packs
  for select using (true);
drop policy if exists "Only list owner manages packs" on public.level_packs;
create policy "Only list owner manages packs" on public.level_packs
  for all to authenticated
  using (auth.uid() = '2194f047-8bc8-4e67-a59d-6738694f5884'::uuid)
  with check (auth.uid() = '2194f047-8bc8-4e67-a59d-6738694f5884'::uuid);
