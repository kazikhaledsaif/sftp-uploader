# Home Server Deployment Guide

This guide is specifically for deploying the SFTP File Uploader on your home server.

---

## 🏠 Recommended Setup: Docker Compose

Docker Compose is perfect for home servers because:
- ✅ Easy to manage
- ✅ All services in one place
- ✅ Easy to update
- ✅ Isolated from your system
- ✅ Can restart automatically

---

## Prerequisites

1. **Docker and Docker Compose installed**
   ```bash
   # Install Docker
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   
   # Add your user to docker group (so you don't need sudo)
   sudo usermod -aG docker $USER
   # Log out and back in for this to take effect
   
   # Install Docker Compose
   sudo apt install docker-compose
   ```

2. **Git installed** (to clone/update the app)
   ```bash
   sudo apt install git
   ```

---

## 🚀 Quick Deployment

### 1. Copy Application to Your Server

```bash
# SSH into your home server
ssh user@your-home-server

# Create directory for the app
mkdir -p ~/apps
cd ~/apps

# Copy the application (choose one method):

# Option A: If you have the files on your Mac
# On your Mac:
scp -r /Users/saif/Documents/ftp_uploder user@your-home-server:~/apps/

# Option B: If using git
git clone <your-repo-url> ftp_uploder
cd ftp_uploder
```

### 2. Configure Environment

```bash
cd ~/apps/ftp_uploder

# Create .env file
cp .env.example .env
nano .env
```

**Edit `.env` with your settings:**
```bash
# SFTP Server (if on same server, use localhost)
SFTP_HOST=localhost  # or your SFTP server IP
SFTP_PORT=22
SFTP_USERNAME=your_username
SFTP_PASSWORD=your_password
SFTP_DEFAULT_DESTINATION=/path/to/uploads
SFTP_TIMEOUT=30

# Redis (Docker will handle this)
REDIS_URL=redis://redis:6379/0

# Rails
RAILS_ENV=production
RAILS_MAX_THREADS=5
SECRET_KEY_BASE=generate_this_with_command_below
```

**Generate SECRET_KEY_BASE:**
```bash
docker run --rm ruby:3.2.0-slim ruby -e "require 'securerandom'; puts SecureRandom.hex(64)"
# Copy the output and paste it as SECRET_KEY_BASE in .env
```

### 3. Start the Application

```bash
# Build and start all services
docker-compose up -d

# Check if everything is running
docker-compose ps

# View logs
docker-compose logs -f
```

### 4. Access Your Application

- **Local network**: http://your-server-ip:3000
- **Example**: http://192.168.1.100:3000

---

## 🔧 Management Commands

### Start/Stop/Restart

```bash
# Start
docker-compose up -d

# Stop
docker-compose down

# Restart
docker-compose restart

# Restart specific service
docker-compose restart web
docker-compose restart sidekiq
```

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f web
docker-compose logs -f sidekiq
docker-compose logs -f redis

# Last 100 lines
docker-compose logs --tail=100
```

### Update Application

```bash
cd ~/apps/ftp_uploder

# Pull latest code (if using git)
git pull

# Rebuild and restart
docker-compose build
docker-compose up -d

# Run migrations if needed
docker-compose exec web rails db:migrate
```

---

## 🌐 Access from Outside Your Home Network

### Option 1: Port Forwarding (Simple)

1. **Forward port 3000** on your router to your server's IP
2. **Find your public IP**: https://whatismyipaddress.com
3. **Access**: http://your-public-ip:3000

⚠️ **Security**: This exposes your app to the internet. Consider adding authentication.

### Option 2: Reverse Proxy with Nginx (Recommended)

Install Nginx on your server:

```bash
sudo apt install nginx
```

Create Nginx config `/etc/nginx/sites-available/ftp-uploder`:

```nginx
server {
    listen 80;
    server_name your-domain.com;  # or your-server-ip

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable and restart:
```bash
sudo ln -s /etc/nginx/sites-available/ftp-uploder /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

Now access via: http://your-server-ip

### Option 3: Cloudflare Tunnel (Free, Secure)

1. **Sign up** at https://dash.cloudflare.com
2. **Install cloudflared**:
   ```bash
   wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
   sudo dpkg -i cloudflared-linux-amd64.deb
   ```

3. **Create tunnel**:
   ```bash
   cloudflared tunnel login
   cloudflared tunnel create ftp-uploder
   cloudflared tunnel route dns ftp-uploder your-subdomain.your-domain.com
   ```

4. **Configure tunnel** (`~/.cloudflared/config.yml`):
   ```yaml
   tunnel: <tunnel-id>
   credentials-file: /home/user/.cloudflared/<tunnel-id>.json

   ingress:
     - hostname: your-subdomain.your-domain.com
       service: http://localhost:3000
     - service: http_status:404
   ```

5. **Run tunnel**:
   ```bash
   cloudflared tunnel run ftp-uploder
   ```

---

## 🔄 Auto-Start on Boot

Create systemd service `/etc/systemd/system/ftp-uploder.service`:

```ini
[Unit]
Description=SFTP File Uploader
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/your-user/apps/ftp_uploder
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
User=your-user

[Install]
WantedBy=multi-user.target
```

Enable auto-start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable ftp-uploder
sudo systemctl start ftp-uploder
```

---

## 📊 Monitoring

### Check Status

```bash
# Service status
docker-compose ps

# Resource usage
docker stats

# Disk usage
docker system df
```

### Sidekiq Dashboard

Access at: http://your-server-ip:3000/sidekiq

Monitor:
- Active jobs
- Failed jobs
- Queue status
- Worker performance

---

## 🔒 Security Recommendations

1. **Firewall**
   ```bash
   sudo ufw allow 22    # SSH
   sudo ufw allow 80    # HTTP
   sudo ufw allow 443   # HTTPS (if using SSL)
   sudo ufw enable
   ```

2. **Change default port** (edit `docker-compose.yml`):
   ```yaml
   ports:
     - "8080:3000"  # Access on port 8080 instead
   ```

3. **Add authentication** (optional)
   - Consider adding HTTP basic auth via Nginx
   - Or implement user authentication in the app

4. **Regular updates**
   ```bash
   # Update system
   sudo apt update && sudo apt upgrade

   # Update Docker images
   docker-compose pull
   docker-compose up -d
   ```

---

## 💾 Backup

### Database Backup

```bash
# Backup SQLite database
docker-compose exec web tar czf /tmp/backup.tar.gz db/
docker cp $(docker-compose ps -q web):/tmp/backup.tar.gz ./backup-$(date +%Y%m%d).tar.gz
```

### Full Backup

```bash
# Backup entire application directory
cd ~/apps
tar czf ftp_uploder-backup-$(date +%Y%m%d).tar.gz ftp_uploder/
```

### Automated Backups (Cron)

```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * cd ~/apps && tar czf ftp_uploder-backup-$(date +\%Y\%m\%d).tar.gz ftp_uploder/ && find ~/apps -name "ftp_uploder-backup-*.tar.gz" -mtime +7 -delete
```

---

## 🆘 Troubleshooting

### Application won't start

```bash
# Check logs
docker-compose logs

# Check if ports are available
sudo netstat -tlnp | grep 3000

# Restart everything
docker-compose down
docker-compose up -d
```

### Out of disk space

```bash
# Clean up Docker
docker system prune -a

# Remove old images
docker image prune -a
```

### Can't access from other devices

```bash
# Check if service is listening
sudo netstat -tlnp | grep 3000

# Check firewall
sudo ufw status

# Test from another device
curl http://your-server-ip:3000
```

---

## 📈 Performance Tuning

For home servers with limited resources:

**Edit `docker-compose.yml`** to limit resources:

```yaml
services:
  web:
    # ... existing config ...
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M

  sidekiq:
    # ... existing config ...
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
```

---

## ✅ Post-Deployment Checklist

- [ ] Application accessible on local network
- [ ] SFTP credentials configured and tested
- [ ] Sidekiq processing jobs
- [ ] Auto-start on boot configured
- [ ] Backups scheduled
- [ ] Firewall configured
- [ ] (Optional) External access configured
- [ ] (Optional) SSL certificate installed

---

## 🎉 You're Done!

Your SFTP File Uploader is now running on your home server!

**Access it at**: http://your-server-ip:3000

For questions or issues, check:
- [HOME_SERVER_DEPLOY.md](HOME_SERVER_DEPLOY.md)
