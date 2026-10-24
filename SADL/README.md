# SADL — starter website

This folder contains a responsive Geometry Dash community demonlist website.

## What works right now
- Pointercrate-inspired dark, competitive layout
- Search/filter, add/edit/delete levels
- Completion proof links
- JSON backup export/import
- Saves in the current browser using local storage

**Important:** this starter is in LOCAL PREVIEW mode. Changes do not sync to your friends or to other devices. GitHub Pages is a static host, so shared editing requires a database and sign-in. Do not put database secret/service-role keys in browser code.

## Publish the preview free with GitHub Pages
1. Make/sign into a GitHub account.
2. Create a new **public** repository named `SADL`.
3. Upload `index.html` to the repository's top level (root). You can upload `README.md` too.
4. Open the repository's **Settings → Pages**.
5. Under **Build and deployment**, choose **Deploy from a branch**, select `main` and `/(root)`, then **Save**.
6. Wait a few minutes, then use the site URL shown in Settings → Pages. GitHub says publishing may take up to 10 minutes.
7. Your site will be public. Do not put private information in it.

Official guide: https://docs.github.com/en/pages/getting-started-with-github-pages/creating-a-github-pages-site

## To let all friends edit the same live list
The uploaded version is a visual/functional preview only. To make shared editing real, connect a hosted database such as Supabase and add sign-in + access rules. This needs a few more setup steps and database configuration; don't share one password among everyone or put a secret key in `index.html`.

Supabase docs:
- https://supabase.com/docs/guides/auth
- https://supabase.com/docs/guides/getting-started/quickstarts/react

Suggested setup for the shared version:
1. Create a Supabase project.
2. Create a `levels` table for the list data.
3. Enable Row Level Security (RLS).
4. Require each friend to sign in and restrict writes to authenticated members.
5. Connect the public website using only the publishable/anon key. Never expose a service-role/secret key.
6. Keep a moderator/backup plan so accidental deletions can be recovered.

The current starter is intentionally not pretending to provide multi-user sync until those pieces are configured.
