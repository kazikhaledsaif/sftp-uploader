# SFTP File Uploader

A modern web application for downloading files from URLs and uploading them to an SFTP server with real-time progress tracking.

## Features

✅ **Easy File Downloads** - Paste any URL and download to your SFTP server  
✅ **Real-time Progress** - Watch download and upload progress in real-time  
✅ **Pause/Resume** - Pause and resume downloads at any time  
✅ **Cancel Downloads** - Stop unwanted downloads  
✅ **Configurable Paths** - Set custom destination paths for each download  
✅ **Background Processing** - Uses Sidekiq for efficient background jobs  
✅ **Beautiful UI** - Modern, responsive interface with dark theme  
✅ **Download History** - Track all your downloads with status indicators  

## Quick Start

### Development (Local)

1. **Install dependencies:**
   ```bash
   bundle install
   ```

2. **Setup database:**
   ```bash
   rails db:migrate
   ```

3. **Configure SFTP settings:**
   Create `.env` file:
   ```bash
   cp .env.example .env
   nano .env  # Add your SFTP credentials
   ```

4. **Start Redis:**
   ```bash
   brew services start redis  # macOS
   # or
   sudo systemctl start redis  # Linux
   ```

5. **Start the application:**
   ```bash
   chmod +x start.sh
   ./start.sh
   ```

6. **Access the app:**
   Open http://localhost:3000 in your browser

### Production (Home Server)

**One-command deployment:**
```bash
./deploy.sh
```

Or manually with Docker:
```bash
cp .env.example .env
nano .env  # Configure your SFTP credentials
docker-compose up -d
```

**See detailed guide:**
- 🏠 [Home Server Deployment](HOME_SERVER_DEPLOY.md)


## Usage

1. **Add a Download:**
   - Paste the download URL
   - Optionally set a custom filename
   - Set the destination path on your SFTP server
   - Click "Start Download"

2. **Monitor Progress:**
   - Watch real-time progress bars
   - See download status (pending, downloading, completed, etc.)
   - View file size and creation time

3. **Manage Downloads:**
   - **Pause** - Temporarily stop a download
   - **Resume** - Continue a paused download
   - **Cancel** - Stop and remove a download
   - **Delete** - Remove from history

## Architecture

- **Backend**: Ruby on Rails 7.1
- **Background Jobs**: Sidekiq with Redis
- **SFTP**: Net::SFTP gem
- **HTTP Client**: HTTParty
- **Database**: SQLite3
- **Frontend**: HTML, CSS, JavaScript (no framework needed)

## Configuration

### SFTP Settings

Edit `config/sftp_config.yml`:

```yaml
development:
  host: "localhost"          # SFTP server hostname
  port: 22                   # SFTP port
  username: "user"           # SFTP username
  password: "pass"           # SFTP password
  default_destination: "/uploads"  # Default upload path
  timeout: 30                # Connection timeout
```

### Environment Variables

You can also use environment variables:

```bash
export REDIS_URL="redis://localhost:6379/0"
export SFTP_HOST="your.server.com"
export SFTP_USERNAME="username"
export SFTP_PASSWORD="password"
```

## Deployment

### Using Docker (Recommended)

Create a `Dockerfile`:

```dockerfile
FROM ruby:3.2
WORKDIR /app
COPY Gemfile* ./
RUN bundle install
COPY . .
RUN rails db:migrate
CMD ["./start.sh"]
```

### Manual Deployment

1. Set up production database
2. Configure production SFTP settings
3. Set environment variables
4. Run migrations
5. Start services with systemd or similar

## Troubleshooting

**Redis connection error:**
```bash
brew services restart redis
```

**SFTP connection failed:**
- Check your SFTP credentials in `config/sftp_config.yml`
- Ensure the SFTP server is accessible
- Verify the destination path exists

**Downloads stuck:**
- Check Sidekiq is running
- View Sidekiq dashboard at http://localhost:3000/sidekiq
- Check logs in `log/development.log`

## Development

**View logs:**
```bash
tail -f log/development.log
```

**Rails console:**
```bash
rails console
```

**Check Sidekiq jobs:**
Visit http://localhost:3000/sidekiq

## License

MIT

## Support

For issues or questions, check the logs or open an issue.
