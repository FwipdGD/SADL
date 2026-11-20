-- SADL: separate level banner artwork from the normal level thumbnail.
-- Run this once in the Supabase SQL Editor.
alter table public.levels
  add column if not exists banner_url text not null default '';

-- Level submissions also need to carry the optional banner until approval.
alter table public.level_submissions
  add column if not exists banner_url text;
