# SA Demonlist

A static Geometry Dash community demonlist for a small group of players. The public name is **SA Demonlist**.

## What the site includes

- Ranked levels with optional thumbnails, creators, difficulty, showcase links and notes.
- Exact-rank placement editing; the other entries shift automatically.
- Player leaderboard with points based on each player's completed levels.
- Completion records and proof links.
- Local preview mode for testing.
- Optional shared online data and member sign-in through Supabase.

## Current status

The GitHub Pages site is published, but it starts in **local preview mode** until Supabase is configured. Local preview saves data only in the current browser. It is not shared between people. The site does not count real website visitors; it counts levels, players and completion records. YouTube view counts are not fetched automatically.

## Turn on shared editing

1. Create a project at https://supabase.com/ and open its SQL Editor.
2. Open `supabase-setup.sql` in this repository, copy all of it into a new Supabase SQL query, and run it.
3. In Supabase project settings, find the **Project URL** and the browser-safe **publishable/anon key**. Never use or publish the service-role/secret key.
4. In GitHub, open `index.html`, click the pencil/edit icon, and find these two lines near the start of the script:
   ```js
   const SUPABASE_URL="PASTE_SUPABASE_PROJECT_URL_HERE",SUPABASE_ANON_KEY="PASTE_SUPABASE_ANON_KEY_HERE";
   ```
   Replace the two placeholder values with your Project URL and publishable/anon key, keeping the quotation marks. Commit the change.
5. In Supabase Authentication settings, set the site URL to `https://fwipdgd.github.io/SADL/` and allow that URL as a redirect URL.
6. Each person signs in with an email they can access and uses the emailed sign-in link. In Supabase Dashboard → Authentication → Users, find their user UUID. Add only the people allowed to edit with a SQL statement in the SQL Editor, replacing the example UUID and display name:
   ```sql
   insert into public.members (user_id, display_name)
   values ('PASTE-USER-UUID-HERE', 'Player display name');
   ```
   Repeat for each approved editor. The site only allows approved members to edit. Public visitors can view the list.
7. Refresh the site. Once the connection message says the shared list is online, edits are stored in the shared database.

## Points

The current simple scoring formula is `1000 / rank`, rounded to one decimal place. It rewards completions of higher-ranked levels more heavily. A player's score recalculates when a level's rank changes.

## Notes

- This is an unofficial fan project, not affiliated with Pointercrate or RobTop Games.
- Do not put private API keys, especially a Supabase service-role key, in the website.
- Use thumbnail links to public images you have permission to use.
