# Refuse to start in production without a login, so the downloader is never
# left open on the network by accident. (Skipped while building assets.)
if Rails.env.production? && ENV["SECRET_KEY_BASE_DUMMY"].blank? && ENV["AUTH_USERNAME"].blank? &&
   ENV["ALLOW_NO_AUTH"] != "true"
  raise "Set AUTH_USERNAME and AUTH_PASSWORD in .env (or ALLOW_NO_AUTH=true if you really want no login)."
end
