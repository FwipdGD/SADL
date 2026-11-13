-- SA Demonlist V7 beta migration
-- Run once before testing beta-v7.html.
alter table public.players add column if not exists banner_url text not null default '';
alter table public.players drop constraint if exists players_banner_url_length;
alter table public.players add constraint players_banner_url_length check (char_length(banner_url) <= 2048);
alter table public.levels add column if not exists tags text[] not null default '{}';
alter table public.levels drop constraint if exists levels_tags_limit;
alter table public.levels add constraint levels_tags_limit check (cardinality(tags) <= 12);
