# Popcorn

A small web app for your homelab (downloader now, watch tracker next): paste a link on your phone, pick a folder
(Movies, TV Series, Downloads…), and **aria2** downloads it straight into your
media folders, using many connections per file and several downloads at once.

- Mobile-first page with live progress, speed and time left
- Pause, resume, retry, cancel, remove from list, delete file
- Downloads queue when the limit is reached; "too many requests" (HTTP 429/503)
  answers are retried automatically with a growing wait
- Survives restarts (aria2 keeps its session; the history is in SQLite)
- Only plain HTTP/HTTPS links; torrents and metalinks are rejected

## Quick start (Docker)

```bash
cp .env.example .env
nano .env          # AUTH_*, SECRET_KEY_BASE, ARIA2_RPC_SECRET, MEDIA_ROOT
docker compose up -d --build
```

Open `http://<server-ip>:3000` and log in. Both containers (`web` and `aria2`)
show up as one `sftp-downloader` group in Docker.

`MEDIA_ROOT` is the folder on the server that holds your media folders. It is
mounted in the containers as `/data`, so the "Save to" choices point at
`/data/Movies`, `/data/TV` and so on. Change them with `DOWNLOAD_DESTINATIONS`.

Full setup on Proxmox (and saving to a Samba share): see [HOMELAB.md](HOMELAB.md).
All settings are listed in [.env.example](.env.example).

## How it works

```text
Phone ──▶ web (Rails 7.1, SQLite) ──JSON-RPC──▶ aria2 (not exposed)
                    │                              │
                    └──────── MEDIA_ROOT → /data ──┘
```

The web container asks aria2 for progress every few seconds (in the background,
so retries and completions are picked up even with the page closed) and stores
it in SQLite with a single writer, so many downloads at once don't lock the database.

## Useful commands

```bash
docker compose ps                 # status
docker compose logs -f web        # app logs
docker compose logs -f aria2      # download engine logs
docker compose up -d --build      # update after pulling changes
```

Health check (for Uptime Kuma): `http://<server-ip>:3000/up` (no login).

## License

MIT
