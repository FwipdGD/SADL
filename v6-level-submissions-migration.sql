-- SADL V6: public level submissions with admin approval
-- Run this in Supabase SQL Editor before publishing V6.
-- Public visitors may submit suggestions, but only the SADL admin can approve/reject them.
-- Approved suggestions are added at the bottom of the ranked list.

create table if not exists public.level_submissions (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 100),
  creator text check (creator is null or char_length(creator) <= 100),
  difficulty text not null default 'Extreme Demon'
    check (difficulty in ('Extreme Demon','Insane Demon','Hard Demon','Medium Demon','Easy Demon','Other')),
  level_id text check (level_id is null or char_length(level_id) <= 30),
  thumbnail_url text check (thumbnail_url is null or char_length(thumbnail_url) <= 2048),
  showcase_url text check (showcase_url is null or char_length(showcase_url) <= 2048),
  notes text check (notes is null or char_length(notes) <= 240),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);

alter table public.level_submissions enable row level security;

drop policy if exists "Anyone can submit a level" on public.level_submissions;
create policy "Anyone can submit a level"
  on public.level_submissions for insert to anon, authenticated
  with check (status = 'pending');

drop policy if exists "Admin can view level submissions" on public.level_submissions;
create policy "Admin can view level submissions"
  on public.level_submissions for select to authenticated
  using (auth.uid() = '2194f047-8bc8-4e67-a59d-6738694f5884'::uuid);

revoke all on public.level_submissions from anon, authenticated;
grant insert on public.level_submissions to anon, authenticated;
grant select on public.level_submissions to authenticated;

create or replace function public.review_level_submission(
  p_submission_id uuid,
  p_approve boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  submission public.level_submissions%rowtype;
  next_rank integer;
begin
  if auth.uid() is distinct from '2194f047-8bc8-4e67-a59d-6738694f5884'::uuid then
    raise exception 'Only the SADL admin can review level submissions';
  end if;

  select * into submission
  from public.level_submissions
  where id = p_submission_id and status = 'pending'
  for update;

  if not found then
    raise exception 'Pending level submission not found';
  end if;

  if p_approve then
    select coalesce(max(rank), 0) + 1 into next_rank from public.levels;

    insert into public.levels (
      name, creator, difficulty, thumbnail_url, showcase_url, notes, rank,
      verifier_player_id, verifier_rank_at_verification
    ) values (
      submission.name, submission.creator, submission.difficulty,
      submission.thumbnail_url, submission.showcase_url, submission.notes,
      next_rank, null, null
    );

    update public.level_submissions
    set status = 'approved', reviewed_at = now()
    where id = p_submission_id;
  else
    update public.level_submissions
    set status = 'rejected', reviewed_at = now()
    where id = p_submission_id;
  end if;
end;
$$;

revoke all on function public.review_level_submission(uuid, boolean) from public;
grant execute on function public.review_level_submission(uuid, boolean) to authenticated;
