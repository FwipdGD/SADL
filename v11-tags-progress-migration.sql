-- SA Demonlist V11: tag-aware level suggestions and Pointercrate-style progress eligibility.
-- Run once in Supabase Dashboard > SQL Editor > New query.
-- Safe for existing data: existing levels keep their tags and receive a 50% default threshold.

begin;

alter table public.levels
  add column if not exists tags text[] not null default '{}',
  add column if not exists min_percent integer not null default 50;

alter table public.level_submissions
  add column if not exists tags text[] not null default '{}';

-- Pointercrate allows level-specific thresholds below 50% (for example, some Main List levels have a 37% requirement).
-- Update the existing record checks so qualifying progress can be submitted at the configured level threshold.
alter table public.levels
  drop constraint if exists levels_min_percent_valid;
alter table public.levels
  add constraint levels_min_percent_valid check (min_percent between 1 and 99);

alter table public.level_runs
  drop constraint if exists level_runs_percent_check;
alter table public.level_runs
  drop constraint if exists level_runs_percent_valid;
alter table public.level_runs
  add constraint level_runs_percent_valid check (percent between 1 and 99);

alter table public.record_submissions
  drop constraint if exists record_submission_percent_valid;
alter table public.record_submissions
  add constraint record_submission_percent_valid check (
    (submission_type = 'completion' and percent is null)
    or (submission_type = 'percent' and percent between 1 and 99)
  );

drop policy if exists "Anyone can submit records for review" on public.record_submissions;
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

alter table public.level_submissions
  drop constraint if exists level_submissions_tags_limit;
alter table public.level_submissions
  add constraint level_submissions_tags_limit check (cardinality(tags) <= 12);

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
      name, creator, difficulty, gd_level_id, thumbnail_url, showcase_url, notes, tags, min_percent, rank,
      verifier_player_id, verifier_rank_at_verification
    ) values (
      submission.name, coalesce(submission.creator, ''), submission.difficulty, submission.level_id,
      coalesce(submission.thumbnail_url, ''), coalesce(submission.showcase_url, ''), coalesce(submission.notes, ''),
      coalesce(submission.tags, '{}'), 50, next_rank, null, null
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

commit;
