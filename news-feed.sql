-- SA Demonlist shared News feed
-- Run once in Supabase SQL Editor. Trigger-generated events are visible to all visitors.

create table if not exists public.news_events (
  id bigint generated always as identity primary key,
  event_type text not null,
  title text not null,
  message text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.news_events enable row level security;
drop policy if exists "News is publicly readable" on public.news_events;
create policy "News is publicly readable" on public.news_events
  for select to anon, authenticated using (true);
revoke insert, update, delete on public.news_events from anon, authenticated;

create or replace function public.sadl_news_event(
  p_type text, p_title text, p_message text, p_details jsonb default '{}'::jsonb
) returns void language plpgsql security definer set search_path=public as $$
begin
  insert into public.news_events(event_type,title,message,details)
  values(p_type,p_title,p_message,coalesce(p_details,'{}'::jsonb));
end; $$;

create or replace function public.sadl_news_levels()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if tg_op='INSERT' then
    perform public.sadl_news_event('level_placed','New level placement',
      coalesce(new.name,'A level')||' has been placed at #'||new.rank||' on the SA Demonlist.',
      jsonb_build_object('level_id',new.id,'rank',new.rank));
    return new;
  elsif tg_op='UPDATE' then
    if old.rank is distinct from new.rank then
      perform public.sadl_news_event('level_moved','Ranking update',
        coalesce(new.name,'A level')||' moved from #'||old.rank||' to #'||new.rank||'. The levels between those positions have shifted accordingly.',
        jsonb_build_object('level_id',new.id,'old_rank',old.rank,'new_rank',new.rank));
    elsif row(old.name,old.creator,old.difficulty,old.thumbnail_url,old.showcase_url,old.notes,old.tags)
       is distinct from row(new.name,new.creator,new.difficulty,new.thumbnail_url,new.showcase_url,new.notes,new.tags) then
      perform public.sadl_news_event('level_updated','Level details updated',
        coalesce(new.name,'A level')||' has had its level details updated.',
        jsonb_build_object('level_id',new.id,'rank',new.rank));
    end if;
    return new;
  end if;
  return null;
end; $$;

create or replace function public.sadl_news_players()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  perform public.sadl_news_event('player_joined','New player joined',
    coalesce(new.name,'A new player')||' has joined the SA Demonlist community.',
    jsonb_build_object('player_id',new.id,'country_code',new.country_code));
  return new;
end; $$;

create or replace function public.sadl_news_completions()
returns trigger language plpgsql security definer set search_path=public as $$
declare player_name text; level_name text; level_rank integer;
begin
  select name into player_name from public.players where id=new.player_id;
  select name,rank into level_name,level_rank from public.levels where id=new.level_id;
  perform public.sadl_news_event('completion','New completion',
    coalesce(player_name,'A player')||' has beaten '||coalesce(level_name,'a level')||
    coalesce(' at #'||level_rank,'')||'.',
    jsonb_build_object('player_id',new.player_id,'level_id',new.level_id,'rank',level_rank));
  return new;
end; $$;

drop trigger if exists sadl_news_levels_insert on public.levels;
drop trigger if exists sadl_news_levels_update on public.levels;
create trigger sadl_news_levels_insert after insert on public.levels
for each row execute function public.sadl_news_levels();
create trigger sadl_news_levels_update after update on public.levels
for each row execute function public.sadl_news_levels();

drop trigger if exists sadl_news_players_insert on public.players;
create trigger sadl_news_players_insert after insert on public.players
for each row execute function public.sadl_news_players();

drop trigger if exists sadl_news_completions_insert on public.completions;
create trigger sadl_news_completions_insert after insert on public.completions
for each row execute function public.sadl_news_completions();

grant select on public.news_events to anon, authenticated;
