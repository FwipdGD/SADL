-- SA Demonlist: add persistent level tags to an existing database.
-- Run this once in Supabase Dashboard > SQL Editor > New query.
-- Existing levels are preserved and receive an empty tag array.

alter table public.levels
  add column if not exists tags text[] not null default '{}';
