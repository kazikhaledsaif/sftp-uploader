# Refuse to start in production without a login, so the downloader is never
# left open on the network by accident. (Skipped while building assets.)
if Rails.env.production? && ENV["SECRET_KEY_BASE_DUMMY"].blank? && ENV["AUTH_USERNAME"].blank? &&
   ENV["ALLOW_NO_AUTH"] != "true"
  raise "No login is configured. Set ALLOW_NO_AUTH=true in .env for no login, " \
        "or set AUTH_USERNAME and AUTH_PASSWORD to require one."
end
