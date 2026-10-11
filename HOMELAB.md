# Deploying Popcorn on the homelab

Popcorn runs as three containers in one `sftp-downloader` group:

| Container | What it does |
|---|---|
| `web` | The app (watchlist, diary, calendar, downloads) on port 9000 |
| `aria2` | Downloads files into your media folders (not reachable from outside) |
| `backup` | Copies the database to `./backups` once a day, keeps 14 days |

Movies and TV are saved in the folder layout Jellyfin expects:
`Movies/Dangal (2016)/Dangal (2016).mkv`, `TV/Panchayat (2020)/Season 03/Panchayat (2020) S03E01.mkv`.

You need a Linux machine (or Proxmox CT) with **Docker** and **git**. About 300 MB of RAM is enough.

---

## 1. Give the Docker CT your media folders (Proxmox only)

Skip this if Docker runs directly on the machine that has the disks.

**On the Proxmox host**, replace `<CTID>` with the CT that runs Docker (`pct list`):

```bash
mkdir -p /mnt/pve/storage/Downloads
chown 101000:101000 /mnt/pve/storage/Downloads    # same owner as Movies/TV

pct set <CTID> -mp1 /mnt/pve/storage,mp=/mnt/storage
pct reboot <CTID>
```

The CT needs `nesting=1,keyctl=1` (Options > Features) for Docker. Inside the CT the
folders now appear at `/mnt/storage/Movies`, `/mnt/storage/TV` and `/mnt/storage/Downloads`.

Saving to a Samba/NFS share instead? Mount it at `/mnt/storage` (for example via
`/etc/fstab`) and answer `none` later for `ARIA2_FILE_ALLOCATION` in `.env`.

## 2. Install

**Inside the CT:**

```bash
git clone git@github.com:kazikhaledsaif/sftp-uploader.git popcorn
cd popcorn
bin/setup
```

`bin/setup` asks for:

- login username and password
- the media folder (`/mnt/storage`)
- the port (`9000`)
- your time zone
- a TMDB key (optional; you can add it later)

It then generates the secret keys, creates `Movies/`, `TV/` and `Downloads/`, builds
and starts Popcorn, and prints the address to open, for example `http://192.168.1.50:9000`.

## 3. Add it to your phone

- **iPhone:** open the address in Safari, tap Share, then **Add to Home Screen**.
- **Android:** open the address in Chrome, tap the menu, then **Add to Home screen**.
  It runs as a full-screen app only over `https://` (for example through Tailscale);
  over plain `http://` it opens as a Chrome shortcut.

## 4. Posters and scores (optional)

Edit `.env` and set:

- `TMDB_API_KEY`: free at https://www.themoviedb.org/settings/api. Enables posters,
  cast, trailers, search and Discover.
- `OMDB_API_KEY`: free at https://www.omdbapi.com/apikey.aspx. Adds IMDb, Rotten
  Tomatoes and Metacritic scores.

Then restart: `docker compose up -d --force-recreate`.

## Everyday commands

```bash
bin/update                      # get the latest version and restart (data is kept)
docker compose ps               # are all three containers up?
docker compose logs -f web      # app log
docker compose logs -f aria2    # download log
docker compose restart          # restart everything
```

Health check for Uptime Kuma: `http://<CT-IP>:9000/up` (no login needed).

## Backups

The `backup` container saves `backups/popcorn-YYYY-MM-DD.sqlite3` every day and keeps
14 days (`BACKUP_DIR` and `BACKUP_KEEP_DAYS` in `.env`). Your media files are not part
of it; back those up as you do today.

To restore a backup:

```bash
docker compose stop web
docker compose exec backup rm -f /storage/production.sqlite3-wal /storage/production.sqlite3-shm
docker compose cp backups/popcorn-2026-10-11.sqlite3 backup:/storage/production.sqlite3
docker compose start web
```

## Settings in `.env`

| Variable | Default | What it does |
|---|---|---|
| `AUTH_USERNAME` / `AUTH_PASSWORD` | | Login for the web page |
| `MEDIA_ROOT` | `/mnt/storage` | Folder with Movies/, TV/, Downloads/ (mounted as `/data`) |
| `APP_PORT` | `9000` | Port of the web page |
| `TIME_ZONE` | `UTC` | For "watched on" dates, e.g. `Asia/Kolkata` |
| `DOWNLOAD_DESTINATIONS` | Movies, TV Series, Downloads | "Save to" choices: `Label=/data/<folder>,...` |
| `ARIA2_CONNECTIONS` | `16` | Connections per file (1-16) |
| `ARIA2_MAX_CONCURRENT` | `5` | Downloads at the same time; the rest wait in the queue |
| `ARIA2_SPEED_LIMIT` | `0` | Total speed cap, e.g. `5M` (0 = unlimited) |
| `ARIA2_FILE_ALLOCATION` | `falloc` | Use `none` on Samba/NFS mounts |
| `TMDB_API_KEY` / `OMDB_API_KEY` | | Posters, details and critic scores |
| `BACKUP_DIR` / `BACKUP_KEEP_DAYS` | `./backups` / `14` | Daily database backups |
| `APP_HOSTS` | (any) | Allowed hostnames, e.g. `popcorn.home` |

Keep Popcorn on your home network. For access from outside, use Tailscale rather than
opening a port on your router.
