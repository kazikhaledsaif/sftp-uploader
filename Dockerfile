# Use official Ruby image
# Debian bookworm base (the old 3.2.0 image was on bullseye, whose apt mirrors are gone)
FROM ruby:3.2-slim-bookworm

# Install dependencies
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    sqlite3 \
    libsqlite3-dev \
    libyaml-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy Gemfile and install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy application code
COPY . .

# Precompile assets for production (no real secrets needed at build time)
RUN SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production bundle exec rails assets:precompile

# Create necessary directories (storage/ holds the production SQLite database)
RUN mkdir -p tmp/pids tmp/cache tmp/sockets log storage

# Expose port
EXPOSE 3000

# Start script
COPY docker-entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["rails", "server", "-b", "0.0.0.0"]
