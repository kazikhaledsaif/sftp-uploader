# Homelab deployment (Proxmox + aria2)

Runs the app with **aria2** as the download engine, saving straight into the
HDD folders that Jellyfin already reads. Two containers (`web` + `aria2`), shown
as one `sftp-downloader` group in Docker.

```text
Browser ──▶ web (Rails, :3000) ──JSON-RPC──▶ aria2 (internal only)
                │                                 │
                └──────────── /data  (= MEDIA_ROOT, one bind mount) ──────────┘
     Proxmox host: /mnt/pve/storage/{Movies,TV,Downloads}
     Jellyfin CT 102 sees the same files at /media/{Movies,TV}
```

Only plain **HTTP/HTTPS** links are accepted. BitTorrent, magnet and metalink
support is switched off in aria2 and `.torrent` links are rejected by the app.
Use it only for files you are allowed to download.

RAM use: roughly 150–250 MB for `web` and ~20 MB for `aria2`.

---

## 1. Give the Docker CT the three folders

**Run on the Proxmox host.** Replace `<CTID>` with the CT that runs Docker
(check with `pct list`) and use mount-point numbers that are free in
`pct config <CTID>` (here `mp1`–`mp3`).

```bash
mkdir -p /mnt/pve/storage/Downloads
chown 101000:101000 /mnt/pve/storage/Downloads   # same owner as Movies/TV

pct set <CTID> -mp1 /mnt/pve/storage/Movies,mp=/mnt/storage/Movies
pct set <CTID> -mp2 /mnt/pve/storage/TV,mp=/mnt/storage/TV
pct set <CTID> -mp3 /mnt/pve/storage/Downloads,mp=/mnt/storage/Downloads
pct reboot <CTID>
```

The CT needs `nesting=1,keyctl=1` (Options → Features) for Docker.

Containers run as root inside an **unprivileged** CT, which is uid `101000` on
the host — the same owner as `Movies/` and `TV/`, so writes just work.

## 2. Configure

**Inside the CT**, in the app folder:

```bash
cp .env.example .env
nano .env
```

Set at least:

```bash
AUTH_USERNAME=admin
AUTH_PASSWORD=<a strong password>
SECRET_KEY_BASE=<output of: openssl rand -hex 64>
ARIA2_RPC_SECRET=<output of: openssl rand -hex 24>
MEDIA_ROOT=/mnt/storage
```

## 3. Start

```bash
docker compose up -d --build
docker compose ps
```

Open `http://<CT-IP>:3000` and log in.

## 4. Test with a legal file

Paste a Linux ISO or public-domain film link (e.g. from archive.org), name it,
pick **Downloads**, and start. You should see speed, ETA and live progress;
try Pause / Resume / Cancel.

## 5. Monitoring, dashboard, backup

- **Uptime Kuma:** HTTP monitor on `http://<CT-IP>:3000/up` (no login needed)
- **Homarr:** add an app tile for `http://<CT-IP>:3000`
- **Backup:** the history database lives in the `app_storage` Docker volume;
  back up the CT as usual

## Settings you can change in `.env`

| Variable | Default | What it does |
|---|---|---|
| `ARIA2_CONNECTIONS` | `16` | Connections per file (1–16) |
| `ARIA2_MAX_CONCURRENT` | `5` | Downloads running at once; the rest are queued |
| `ARIA2_SPEED_LIMIT` | `0` | Total speed cap, e.g. `5M` |
| `ARIA2_DISK_CACHE` | `64M` | RAM used to batch disk writes |
| `ARIA2_FILE_ALLOCATION` | `falloc` | Use `none` if `MEDIA_ROOT` is a Samba/NFS mount |
| `DOWNLOAD_DESTINATIONS` | Movies/TV/Downloads | "Save to" choices, `Label=/data/<folder>,...` (folders inside `MEDIA_ROOT`) |
| `APP_HOSTS` | (any) | Allowed hostnames, e.g. `downloads.home` |
| `APP_PORT` | `3000` | Port on the CT |

If a server answers "too many requests" (HTTP 429/503), the download goes back
in the queue and is retried automatically after 15 s, 30 s, 60 s… (up to 8 times)
with fewer connections. It continues from where it stopped.

## Saving to a Samba share instead

Mount the share on the machine that runs Docker (e.g. at `/mnt/storage` via
`/etc/fstab` with `cifs`), then set `MEDIA_ROOT=/mnt/storage` and
`ARIA2_FILE_ALLOCATION=none`. Running Docker on the Samba server itself is
faster, since files are written to the disk directly.

Keep it LAN-only. For access from outside, use Tailscale rather than a router
port forward.
