# Popcorn

Your own movie house for the homelab: plan, track and download movies and TV series,
mostly from your phone.

- **Watchlist:** what you want to watch, with search, filters (Hindi/English, genre,
  in library), sort and "Pick for me". Shows you are part-way through show "Next: S3".
- **Diary:** everything you watched, with date, half-star rating and a note, plus
  yearly stats.
- **Calendar:** plan a title for Friday or Saturday night, see release days; after a
  planned date it asks "Did you watch it?".
- **Title pages:** poster, cast, trailer, critic scores and a Wikipedia summary (with
  free TMDB/OMDb keys).
- **Downloads:** paste a link, pick Movies / TV Series / Downloads, and **aria2**
  downloads it into your media folders in the layout Jellyfin expects. Many connections
  per file, several downloads at once, automatic retries. The title goes on your
  Want list.
- **Installable** on your phone's home screen like an app.

## Install

On a Linux server (or Proxmox CT) with Docker and git:

```bash
git clone git@github.com:kazikhaledsaif/sftp-uploader.git popcorn
cd popcorn
bin/setup          # asks a few questions, then starts everything
```

Later, `bin/update` gets the latest version and restarts it. Your data is kept.

The full guide is in [HOMELAB.md](HOMELAB.md): Proxmox folders, phone install, posters,
backups and all settings.

## How it works

```text
Phone ──▶ web (Rails 7.1, SQLite) ──JSON-RPC──▶ aria2 (not exposed)
              │        │                          │
              │        └────── MEDIA_ROOT → /data ┘
              └── backup: daily copy of the database to ./backups
```

All three containers show up as one `sftp-downloader` group in Docker.

Try it with sample data: `docker compose exec web bin/rails popcorn:demo`
(remove it again with `popcorn:demo:clear`).

## License

MIT
