-- SA Demonlist security + record review setup
-- Run this entire script in Supabase SQL Editor as the project owner.
-- It keeps public browsing/submission, but only FWIPGD can edit the actual list or approve records.

begin;

-- Arthur/other accidentally added members must not retain edit access.
delete from public.members
where user_id <> '2194f047-8bc8-4e67-a59d-6738694f5884'::uuid;

create table if not exists public.level_runs (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  level_id uuid not null references public.levels(id) on delete cascade,
  percent integer not null check (percent between 1 and 99),
  proof_url text not null check (length(btrim(proof_url)) > 0),
  achieved_on date,
  created_at timestamptz not null default now()
);

create table if not exists public.record_submissions (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  level_id uuid not null references public.levels(id) on delete cascade,
  submission_type text not null check (submission_type in ('completion','percent')),
  percent integer,
  proof_url text not null check (length(btrim(proof_url)) > 0),
  achieved_on date,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now(),
  constraint record_submission_percent_valid check (
    (submission_type = 'completion' and percent is null)
    or (submission_type = 'percent' and percent between 1 and 99)
  )
);

alter table public.levels enable row level security;
alter table public.players enable row level security;
alter table public.completions enable row level security;
alter table public.members enable row level security;
alter table public.level_runs enable row level security;
alter table public.record_submissions enable row level security;

-- Replace old rules on these tables, including the old public direct-completion insert rule.
do $$
declare p record;
begin
  for p in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in ('levels','players','completions','members','level_runs','record_submissions')
  loop
    execute format('drop policy %I on %I.%I', p.policyname, p.schemaname, p.tablename);
  end loop;
end $$;

create policy "Public can read levels" on public.levels
  for select to anon, authenticated using (true);
create policy "FWIPGD manages levels" on public.levels
  for all to authenticated
  using (auth.uid() = '2194f047-8bc8-4e67-a59d-6738694f5884'::uuid)
  with check (auth.uid() = '2194f047-8bc8-4e67-a59d-6738694f5884'::uuid);

create policy "Public can read players" on public.players
  for select to anon, authenticated using (true);
create policy "FWIPGD manages players" on public.players
  for all to authenticated
  using (auth.uid() = '2194f047-8bc8-4e67-a59d-6738694f5884'::uuid)
  with check (auth.uid() = '2194f047-8bc8-4e67-a59d-6738694f5884'::uuid);

create policy "Public can read completions" on public.completions
  for select to anon, authenticated using (true);
create policy "FWIPGD manages completions" on public.completions
  for all to authenticated
  using (auth.uid() = '2194f047-8bc8-4e67-a59d-6738694f5884'::uuid)
  with check (auth.uid() = '2194f047-8bc8-4e67-a59d-6738694f5884'::uuid);

create policy "FWIPGD can read own membership" on public.members
  for select to authenticated
  using (auth.uid() = '2194f047-8bc8-4e67-a59d-6738694f5884'::uuid);
create policy "FWIPGD manages membership" on public.members
  for all to authenticated
  using (auth.uid() = '2194f047-8bc8-4e67-a59d-6738694f5884'::uuid)
  with check (auth.uid() = '2194f047-8bc8-4e67-a59d-6738694f5884'::uuid);

create policy "Public can read approved progress runs" on public.level_runs
  for select to anon, authenticated using (true);
create policy "FWIPGD manages progress runs" on public.level_runs
  for all to authenticated
  using (auth.uid() = '2194f047-8bc8-4e67-a59d-6738694f5884'::uuid)
  with check (auth.uid() = '2194f047-8bc8-4e67-a59d-6738694f5884'::uuid);

create policy "Anyone can submit records for review" on public.record_submissions
  for insert to anon, authenticated
  with check (
    status = 'pending'
    and length(btrim(proof_url)) > 0
    and (
      (submission_type = 'completion' and percent is null)
      or (submission_type = 'percent' and percent between 1 and 99)
    )
  );
create policy "FWIPGD can view submissions" on public.record_submissions
  for select to authenticated
  using (auth.uid() = '2194f047-8bc8-4e67-a59d-6738694f5884'::uuid);
create policy "FWIPGD can review submissions" on public.record_submissions
  for update to authenticated
  using (auth.uid() = '2194f047-8bc8-4e67-a59d-6738694f5884'::uuid)
  with check (auth.uid() = '2194f047-8bc8-4e67-a59d-6738694f5884'::uuid);
create policy "FWIPGD can remove submissions" on public.record_submissions
  for delete to authenticated
  using (auth.uid() = '2194f047-8bc8-4e67-a59d-6738694f5884'::uuid);

grant select on public.levels, public.players, public.completions, public.level_runs to anon, authenticated;
grant insert, update, delete on public.levels, public.players, public.completions, public.level_runs to authenticated;
revoke insert, update, delete on public.completions from anon, authenticated;
grant insert on public.record_submissions to anon, authenticated;
grant select, update, delete on public.record_submissions to authenticated;
grant select, insert, update, delete on public.members to authenticated;

create or replace function public.review_record_submission(p_submission_id uuid, p_approve boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare s public.record_submissions%rowtype;
begin
  if auth.uid() is distinct from '2194f047-8bc8-4e67-a59d-6738694f5884'::uuid then
    raise exception 'Only FWIPGD can review submissions';
  end if;

  select * into s
  from public.record_submissions
  where id = p_submission_id and status = 'pending'
  for update;

  if not found then
    raise exception 'Submission not found or already reviewed';
  end if;

  if p_approve then
    if s.submission_type = 'completion' then
      if exists (select 1 from public.completions c where c.player_id = s.player_id and c.level_id = s.level_id) then
        raise exception 'That player already has a completion for this level';
      end if;
      insert into public.completions (player_id, level_id, proof_url, beaten_on)
      values (s.player_id, s.level_id, s.proof_url, s.achieved_on);
    else
      insert into public.level_runs (player_id, level_id, percent, proof_url, achieved_on)
      values (s.player_id, s.level_id, s.percent, s.proof_url, s.achieved_on);
    end if;
    update public.record_submissions set status = 'approved' where id = s.id;
  else
    update public.record_submissions set status = 'rejected' where id = s.id;
  end if;
end;
$$;

revoke all on function public.review_record_submission(uuid, boolean) from public;
grant execute on function public.review_record_submission(uuid, boolean) to authenticated;

commit;
