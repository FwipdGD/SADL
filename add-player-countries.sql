-- Add player country support to SA Demonlist.
-- Run this once in the Supabase SQL Editor.
-- Existing players and their records are preserved; country is optional.

alter table public.players
  add column if not exists country_code text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'players_country_code_format'
      and conrelid = 'public.players'::regclass
  ) then
    alter table public.players
      add constraint players_country_code_format
      check (country_code is null or country_code ~ '^[A-Z]{2}$');
  end if;
end $$;

comment on column public.players.country_code is
  'Optional ISO-style two-letter country code used for the SA Demonlist country leaderboard.';
